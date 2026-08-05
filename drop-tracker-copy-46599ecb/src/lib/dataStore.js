import { base44 } from "@/api/base44Client";

const GUEST_KEY = "droptracker_guest_mode";
const MEDS_KEY = "droptracker_medications";
const EVENTS_KEY = "droptracker_dose_events";
const USER_KEY = "droptracker_user";
const PENDING_MIGRATION_KEY = "droptracker_pending_migration";

const DEFAULT_USER = {
  first_name: "",
  waking_start: "07:00",
  waking_end: "21:00",
  onboarded: false,
  has_seen_disclaimer: false,
};

export function isGuest() {
  try {
    return localStorage.getItem(GUEST_KEY) === "true";
  } catch {
    return false;
  }
}

export function setGuestMode(val) {
  try {
    if (val) localStorage.setItem(GUEST_KEY, "true");
    else localStorage.removeItem(GUEST_KEY);
  } catch {}
}

export function hasPendingMigration() {
  try {
    return localStorage.getItem(PENDING_MIGRATION_KEY) === "true";
  } catch {
    return false;
  }
}

export function setPendingMigration(val) {
  try {
    if (val) localStorage.setItem(PENDING_MIGRATION_KEY, "true");
    else localStorage.removeItem(PENDING_MIGRATION_KEY);
  } catch {}
}

function uid() {
  return "g_" + Math.random().toString(36).slice(2, 10) + Date.now().toString(36);
}

function readArr(key) {
  try {
    return JSON.parse(localStorage.getItem(key) || "[]");
  } catch {
    return [];
  }
}

function writeArr(key, arr) {
  try {
    localStorage.setItem(key, JSON.stringify(arr));
  } catch {}
}

function readObj(key, fallback) {
  try {
    return JSON.parse(localStorage.getItem(key) || "null") || fallback;
  } catch {
    return fallback;
  }
}

function writeObj(key, obj) {
  try {
    localStorage.setItem(key, JSON.stringify(obj));
  } catch {}
}

function matchQuery(item, query) {
  if (!query) return true;
  for (const [k, v] of Object.entries(query)) {
    if (v && typeof v === "object" && "$gte" in v) {
      if (!(item[k] >= v.$gte)) return false;
    } else if (item[k] !== v) {
      return false;
    }
  }
  return true;
}

async function localList(key) {
  return readArr(key);
}
async function localFilter(key, query) {
  return readArr(key).filter((i) => matchQuery(i, query));
}
async function localCreate(key, data) {
  const arr = readArr(key);
  const now = new Date().toISOString();
  const record = { id: uid(), created_date: now, updated_date: now, ...data };
  arr.push(record);
  writeArr(key, arr);
  return record;
}
async function localUpdate(key, id, data) {
  const arr = readArr(key);
  const idx = arr.findIndex((x) => x.id === id);
  if (idx === -1) throw new Error("Record not found");
  arr[idx] = { ...arr[idx], ...data, updated_date: new Date().toISOString() };
  writeArr(key, arr);
  return arr[idx];
}
async function localDelete(key, id) {
  writeArr(key, readArr(key).filter((x) => x.id !== id));
}

export const store = {
  medications: {
    list: async () => (isGuest() ? localList(MEDS_KEY) : base44.entities.Medication.list()),
    filter: async (q) => (isGuest() ? localFilter(MEDS_KEY, q) : base44.entities.Medication.filter(q)),
    create: async (d) => (isGuest() ? localCreate(MEDS_KEY, d) : base44.entities.Medication.create(d)),
    update: async (id, d) => (isGuest() ? localUpdate(MEDS_KEY, id, d) : base44.entities.Medication.update(id, d)),
    delete: async (id) => (isGuest() ? localDelete(MEDS_KEY, id) : base44.entities.Medication.delete(id)),
  },
  doseEvents: {
    list: async () => (isGuest() ? localList(EVENTS_KEY) : base44.entities.DoseEvent.list()),
    filter: async (q) => (isGuest() ? localFilter(EVENTS_KEY, q) : base44.entities.DoseEvent.filter(q)),
    create: async (d) => (isGuest() ? localCreate(EVENTS_KEY, d) : base44.entities.DoseEvent.create(d)),
    delete: async (id) => (isGuest() ? localDelete(EVENTS_KEY, id) : base44.entities.DoseEvent.delete(id)),
  },
  user: {
    get: async () => {
      if (isGuest()) return { ...DEFAULT_USER, ...readObj(USER_KEY, {}) };
      return base44.auth.me();
    },
    update: async (d) => {
      if (isGuest()) {
        const u = { ...DEFAULT_USER, ...readObj(USER_KEY, {}), ...d };
        writeObj(USER_KEY, u);
        return u;
      }
      return base44.auth.updateMe(d);
    },
  },
  logout: async (redirectUrl) => {
    if (isGuest()) {
      setGuestMode(false);
      return;
    }
    return base44.auth.logout(redirectUrl);
  },
};

export async function migrateLocalToServer() {
  const localMeds = readArr(MEDS_KEY);
  const localEvents = readArr(EVENTS_KEY);
  const strip = ({ id, created_date, updated_date, created_by_id, ...rest }) => rest;
  if (localMeds.length) await base44.entities.Medication.bulkCreate(localMeds.map(strip));
  if (localEvents.length) await base44.entities.DoseEvent.bulkCreate(localEvents.map(strip));
  localStorage.removeItem(MEDS_KEY);
  localStorage.removeItem(EVENTS_KEY);
  localStorage.removeItem(USER_KEY);
  localStorage.removeItem(PENDING_MIGRATION_KEY);
}