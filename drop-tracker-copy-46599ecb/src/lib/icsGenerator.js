import { isMedicationActiveOn, todayStr, suggestTimes, getInstructionSummary, dateToStr } from "@/lib/doseUtils";

function fmtDate(dateStr) {
  return (dateStr || "").replace(/-/g, "");
}

function fmtTime(hhmm) {
  return (hhmm || "08:00").replace(":", "") + "00";
}

function fmtStampUTC(d) {
  const p = (n) => String(n).padStart(2, "0");
  return `${d.getUTCFullYear()}${p(d.getUTCMonth() + 1)}${p(d.getUTCDate())}T${p(d.getUTCHours())}${p(d.getUTCMinutes())}${p(d.getUTCSeconds())}Z`;
}

function dayBefore(dateStr) {
  const [y, m, d] = dateStr.split("-").map(Number);
  const dt = new Date(y, m - 1, d);
  dt.setDate(dt.getDate() - 1);
  return dateToStr(dt);
}

function escapeICS(text) {
  return String(text || "").replace(/\\/g, "\\\\").replace(/;/g, "\\;").replace(/,/g, "\\,").replace(/\n/g, "\\n");
}

function fold(line) {
  if (line.length <= 75) return line;
  let result = line.slice(0, 75);
  let rest = line.slice(75);
  while (rest.length > 0) {
    result += "\r\n " + rest.slice(0, 74);
    rest = rest.slice(74);
  }
  return result;
}

function eyeLabel(med) {
  return med.eye === "both" ? "both eyes" : med.eye === "right" ? "right eye" : "left eye";
}

function buildDescription(med) {
  const parts = [`Eye: ${eyeLabel(med)}`];
  const instr = getInstructionSummary(med.instructions);
  if (instr.length) parts.push(`Instructions: ${instr.join(". ")}.`);
  if (med.instructions?.notes) parts.push(`Notes: ${med.instructions.notes}`);
  parts.push("Reminder from Drop Tracker. Follow your eye doctor's instructions.");
  return parts.join("\n");
}

function getSegments(med) {
  const segments = [];
  const sortedSteps = [...(med.taper_steps || [])]
    .filter((s) => s.start_date)
    .sort((a, b) => a.start_date.localeCompare(b.start_date));
  const firstStepDate = sortedSteps[0]?.start_date;
  const initialEnd = firstStepDate ? dayBefore(firstStepDate) : med.ongoing ? null : med.end_date;
  const showInitial =
    med.dose_times?.length &&
    med.start_date &&
    (!firstStepDate || firstStepDate > med.start_date) &&
    (initialEnd === null || initialEnd >= med.start_date);
  if (showInitial) {
    segments.push({ startDate: med.start_date, endDate: initialEnd, doseTimes: med.dose_times });
  }
  sortedSteps.forEach((step, i) => {
    const nextStart = sortedSteps[i + 1]?.start_date;
    const end = nextStart ? dayBefore(nextStart) : med.ongoing ? null : med.end_date;
    const times = step.dose_times?.length
      ? step.dose_times
      : suggestTimes(step.frequency_type, "07:00", "21:00");
    if (step.start_date && (!end || end >= step.start_date)) {
      segments.push({ startDate: step.start_date, endDate: end, doseTimes: times });
    }
  });
  return segments;
}

function buildEvents(med) {
  const events = [];
  const title = `${med.name} - ${eyeLabel(med)}`;
  const description = buildDescription(med);
  const segments = getSegments(med);
  segments.forEach((seg, segIdx) => {
    if (!seg.doseTimes || seg.doseTimes.length === 0 || !seg.startDate) return;
    seg.doseTimes.forEach((time, timeIdx) => {
      const dtstart = `${fmtDate(seg.startDate)}T${fmtTime(time)}`;
      let rrule = "FREQ=DAILY";
      if (seg.endDate) rrule += `;UNTIL=${fmtDate(seg.endDate)}T235959`;
      events.push({
        uid: `${med.id}-s${segIdx}-t${timeIdx}@droptracker`,
        title,
        description,
        dtstart,
        rrule,
      });
    });
  });
  return events;
}

function composeICS(events) {
  const lines = [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//Drop Tracker//Eye Drop Reminders//EN",
    "CALSCALE:GREGORIAN",
    "METHOD:PUBLISH",
  ];
  const stamp = fmtStampUTC(new Date());
  for (const ev of events) {
    lines.push(
      "BEGIN:VEVENT",
      `UID:${ev.uid}`,
      `DTSTAMP:${stamp}`,
      `SEQUENCE:0`,
      `DTSTART:${ev.dtstart}`,
      `RRULE:${ev.rrule}`,
      `SUMMARY:${escapeICS(ev.title)}`,
      `DESCRIPTION:${escapeICS(ev.description)}`,
      "BEGIN:VALARM",
      "TRIGGER:PT0M",
      "ACTION:DISPLAY",
      `DESCRIPTION:${escapeICS(ev.title)}`,
      "END:VALARM",
      "END:VEVENT"
    );
  }
  lines.push("END:VCALENDAR");
  return lines.map(fold).join("\r\n");
}

export function generateMedicationICS(med) {
  return composeICS(buildEvents(med));
}

export function generateAllICS(medications) {
  const today = todayStr();
  const active = (medications || []).filter((m) => isMedicationActiveOn(m, today));
  return composeICS(active.flatMap(buildEvents));
}

export function downloadICS(filename, content) {
  const blob = new Blob([content], { type: "text/calendar;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}