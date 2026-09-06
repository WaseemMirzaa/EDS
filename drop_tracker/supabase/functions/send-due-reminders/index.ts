// Drop Tracker — send-due-reminders
//
// Invoked once a minute by pg_cron (see db/migrations/007_push_scheduling.sql).
// Finds every `scheduled_reminders` row that's due and not yet sent, sends an
// FCM data-only push to each of that user's registered devices, and marks the
// row sent. The app itself (FcmService.publishSchedule / publishSnooze) is
// what populates this table — this function does no dose/taper logic of its
// own, deliberately, so there's exactly one place (the Dart client) that
// knows how to compute a dose schedule.
//
// Data-only (no `notification` block) is deliberate: neither platform
// auto-displays it, so the app itself decides whether to show a visual
// alert — see FcmService._handleMessage's doc comment for why (avoiding a
// double-alert when the device's own local scheduling already fired one).
//
// Required secrets (Dashboard → Edge Functions → send-due-reminders →
// Secrets, or `supabase secrets set`):
//   FCM_SERVICE_ACCOUNT_JSON  — the full JSON key downloaded from Firebase
//     Console → Project Settings → Service Accounts → Generate new private
//     key, pasted as a single-line string.
//   FCM_PROJECT_ID            — the Firebase project ID (drop-tracker-eds).
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided automatically by
// the Edge Functions runtime — nothing to set for those.

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { create as createJwt, getNumericDate } from 'https://deno.land/x/djwt@v3.0.2/mod.ts';

const FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';
const TOKEN_URL = 'https://oauth2.googleapis.com/token';

interface ServiceAccount {
  client_email: string;
  private_key: string;
}

/** Converts a PEM private key into a CryptoKey suitable for RS256 signing. */
async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '');
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
}

/** Exchanges the service account for a short-lived FCM access token. */
async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const key = await importPrivateKey(sa.private_key);
  const jwt = await createJwt(
    { alg: 'RS256', typ: 'JWT' },
    {
      iss: sa.client_email,
      scope: FCM_SCOPE,
      aud: TOKEN_URL,
      exp: getNumericDate(60 * 60),
      iat: getNumericDate(0),
    },
    key,
  );

  const res = await fetch(TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  if (!res.ok) {
    throw new Error(`FCM token exchange failed: ${res.status} ${await res.text()}`);
  }
  const json = await res.json();
  return json.access_token as string;
}

async function sendFcm(
  accessToken: string,
  projectId: string,
  pushToken: string,
  data: Record<string, string>,
): Promise<{ ok: boolean; invalidToken: boolean }> {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token: pushToken,
          data,
          // Neither an `android.notification` nor `apns.payload.aps.alert`
          // block — see this file's header comment for why that's
          // deliberate. `apns-priority: 5` (rather than 10) keeps this on
          // Apple's throttled "background" delivery class, which is the
          // honest classification for a data-only push — see
          // FcmService's doc comment on the force-quit limitation this
          // implies.
          android: { priority: 'high' },
          apns: {
            headers: { 'apns-priority': '5', 'apns-push-type': 'background' },
            payload: { aps: { 'content-available': 1 } },
          },
        },
      }),
    },
  );
  if (res.ok) return { ok: true, invalidToken: false };
  const body = await res.text();
  // UNREGISTERED / INVALID_ARGUMENT on a token means the app was
  // uninstalled or the token rotated without us hearing about it — prune
  // it rather than retrying it forever.
  const invalidToken = res.status === 404 ||
    body.includes('UNREGISTERED') ||
    body.includes('INVALID_ARGUMENT');
  console.error(`FCM send failed (${res.status}): ${body}`);
  return { ok: false, invalidToken };
}

Deno.serve(async () => {
  const serviceAccountJson = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON');
  const projectId = Deno.env.get('FCM_PROJECT_ID');
  if (!serviceAccountJson || !projectId) {
    return new Response('Missing FCM_SERVICE_ACCOUNT_JSON or FCM_PROJECT_ID', { status: 500 });
  }
  const sa: ServiceAccount = JSON.parse(serviceAccountJson);

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  const { data: due, error } = await supabase
    .from('scheduled_reminders')
    .select('id, user_id, medication_id, scheduled_date, scheduled_hhmm, medications(name, eye)')
    .is('sent_at', null)
    .lte('fire_at', new Date().toISOString())
    .limit(500); // defensive cap — a single minute's worth should never be this high

  if (error) {
    console.error('Query failed:', error);
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }
  if (!due || due.length === 0) {
    return new Response(JSON.stringify({ sent: 0 }), { status: 200 });
  }

  const accessToken = await getAccessToken(sa);

  const staleTokenIds: string[] = [];
  const sentReminderIds: string[] = [];

  for (const reminder of due) {
    const { data: devices } = await supabase
      .from('devices')
      .select('id, push_token')
      .eq('user_id', reminder.user_id);

    if (!devices || devices.length === 0) {
      // No device to push to — still mark sent so this row doesn't get
      // retried every minute forever; the local schedule on whatever
      // device does exist is still the primary delivery path regardless.
      sentReminderIds.push(reminder.id);
      continue;
    }

    const med = reminder.medications as unknown as { name: string; eye: string } | null;
    let anySucceeded = false;
    for (const device of devices) {
      const { ok, invalidToken } = await sendFcm(accessToken, projectId, device.push_token, {
        type: 'dose_reminder',
        medication_id: reminder.medication_id,
        medication_name: med?.name ?? 'Drop Tracker',
        eye: med?.eye ?? '',
        scheduled_date: reminder.scheduled_date,
        scheduled_hhmm: reminder.scheduled_hhmm,
      });
      if (ok) anySucceeded = true;
      if (invalidToken) staleTokenIds.push(device.id);
    }
    if (anySucceeded || devices.length > 0) sentReminderIds.push(reminder.id);
  }

  if (sentReminderIds.length > 0) {
    await supabase
      .from('scheduled_reminders')
      .update({ sent_at: new Date().toISOString() })
      .in('id', sentReminderIds);
  }
  if (staleTokenIds.length > 0) {
    await supabase.from('devices').delete().in('id', staleTokenIds);
  }

  return new Response(
    JSON.stringify({ sent: sentReminderIds.length, prunedTokens: staleTokenIds.length }),
    { status: 200, headers: { 'Content-Type': 'application/json' } },
  );
});
