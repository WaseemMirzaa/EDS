export const CAP_COLORS = {
  white: { label: "White", hex: "#f1f5f9", ring: "#cbd5e1" },
  pink: { label: "Pink", hex: "#f9a8d4", ring: "#ec4899" },
  tan: { label: "Tan", hex: "#d4b896", ring: "#a16207" },
  red: { label: "Red", hex: "#ef4444", ring: "#b91c1c" },
  green: { label: "Green", hex: "#22c55e", ring: "#15803d" },
  blue: { label: "Blue", hex: "#3b82f6", ring: "#1d4ed8" },
  teal: { label: "Teal", hex: "#14b8a6", ring: "#0f766e" },
  gray: { label: "Gray", hex: "#9ca3af", ring: "#4b5563" },
};

export const FREQUENCY_LABELS = {
  once_daily: "Once daily",
  twice_daily: "Twice daily",
  three_daily: "3× daily",
  four_daily: "4× daily",
  every_n_hours: "Every N hours",
  custom_times: "Custom times",
};

export const FREQUENCY_COUNT = {
  once_daily: 1,
  twice_daily: 2,
  three_daily: 3,
  four_daily: 4,
};

export const EYE_LABELS = {
  right: "Right eye",
  left: "Left eye",
  both: "Both eyes",
};

export const EYE_SHORT = {
  right: "R",
  left: "L",
  both: "Both",
};

export const RESPONSE_META = {
  took_it: { label: "Took it", icon: "✅", color: "#16a34a" },
  not_sure: { label: "Not sure", icon: "🤔", color: "#d97706" },
  snoozed: { label: "Snoozed", icon: "⏰", color: "#2563eb" },
  skipped: { label: "Skipped", icon: "❌", color: "#dc2626" },
};

export function suggestTimes(frequency, wakingStart = "07:00", wakingEnd = "21:00") {
  const count = FREQUENCY_COUNT[frequency];
  if (!count) return [];
  const [sh, sm] = wakingStart.split(":").map(Number);
  const [eh, em] = wakingEnd.split(":").map(Number);
  const startMin = sh * 60 + sm;
  const endMin = eh * 60 + em;
  const span = endMin - startMin;
  if (count === 1) return [wakingStart];
  const interval = Math.round(span / (count - 1));
  const times = [];
  for (let i = 0; i < count; i++) {
    const mins = startMin + interval * i;
    const h = Math.floor(mins / 60);
    const m = mins % 60;
    times.push(`${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}`);
  }
  return times;
}

export function timesForEveryNHours(n, wakingStart = "07:00", wakingEnd = "21:00") {
  const [sh, sm] = wakingStart.split(":").map(Number);
  const [eh, em] = wakingEnd.split(":").map(Number);
  const startMin = sh * 60 + sm;
  const endMin = eh * 60 + em;
  const interval = n * 60;
  const times = [];
  for (let mins = startMin; mins <= endMin; mins += interval) {
    const h = Math.floor(mins / 60);
    const m = mins % 60;
    times.push(`${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}`);
  }
  return times;
}

export function getActiveTaperStep(med, dateStr) {
  if (!med.taper_steps || med.taper_steps.length === 0) return null;
  const sorted = [...med.taper_steps].sort((a, b) => a.start_date.localeCompare(b.start_date));
  let active = null;
  for (const step of sorted) {
    if (step.start_date <= dateStr) active = step;
  }
  return active;
}

export function getDoseTimesForDate(med, dateStr, wakingStart = "07:00", wakingEnd = "21:00") {
  const taper = getActiveTaperStep(med, dateStr);
  const ftype = taper ? taper.frequency_type : med.frequency_type;
  const fval = taper ? taper.frequency_value : med.frequency_value;
  const dtimes = taper ? taper.dose_times : med.dose_times;

  if (ftype === "custom_times" && dtimes && dtimes.length > 0) return dtimes;
  if (ftype === "every_n_hours" && fval) {
    return timesForEveryNHours(fval, wakingStart, wakingEnd);
  }
  if (dtimes && dtimes.length > 0) return dtimes;
  return suggestTimes(ftype, wakingStart, wakingEnd);
}

export function isMedicationActiveOn(med, dateStr) {
  if (med.start_date && med.start_date > dateStr) return false;
  if (!med.ongoing && med.end_date && med.end_date < dateStr) return false;
  return true;
}

export function todayStr() {
  return dateToStr(new Date());
}

export function dateToStr(d) {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

export function strToDate(s) {
  const [y, m, d] = s.split("-").map(Number);
  return new Date(y, m - 1, d);
}

export function getDosesForDate(medications, dateStr, wakingStart = "07:00", wakingEnd = "21:00") {
  const doses = [];
  for (const med of medications) {
    if (!isMedicationActiveOn(med, dateStr)) continue;
    const times = getDoseTimesForDate(med, dateStr, wakingStart, wakingEnd);
    for (const time of times) {
      doses.push({
        medication_id: med.id,
        medication_name: med.name,
        bottle_cap_color: med.bottle_cap_color,
        eye: med.eye,
        scheduled_hhmm: time,
        scheduled_date: dateStr,
        scheduled_time: `${dateStr}T${time}:00`,
        instructions: med.instructions || {},
        category: med.category,
      });
    }
  }
  doses.sort((a, b) => a.scheduled_hhmm.localeCompare(b.scheduled_hhmm));
  return doses;
}

export function formatTime(hhmm) {
  const [h, m] = hhmm.split(":").map(Number);
  const period = h >= 12 ? "PM" : "AM";
  const hr = h === 0 ? 12 : h > 12 ? h - 12 : h;
  return `${hr}:${String(m).padStart(2, "0")} ${period}`;
}

export function formatTimeShort(isoStr) {
  if (!isoStr) return "";
  const d = new Date(isoStr);
  const h = d.getHours();
  const m = d.getMinutes();
  const period = h >= 12 ? "PM" : "AM";
  const hr = h === 0 ? 12 : h > 12 ? h - 12 : h;
  return `${hr}:${String(m).padStart(2, "0")} ${period}`;
}

export function getInstructionSummary(instructions) {
  const parts = [];
  if (!instructions) return parts;
  if (instructions.shake) parts.push("Shake bottle");
  if (instructions.refrigerate) parts.push("Refrigerate");
  if (instructions.wait_5_min) parts.push("Wait 5 min between drops");
  if (instructions.remove_contacts) parts.push("Remove contacts");
  if (instructions.press_tear_duct) parts.push("Press tear duct");
  return parts;
}

export function matchDoseToEvent(dose, events) {
  return events.find(
    (e) =>
      e.medication_id === dose.medication_id &&
      e.scheduled_hhmm === dose.scheduled_hhmm &&
      e.scheduled_date === dose.scheduled_date
  );
}

export function calculateAdherence(scheduledCount, takenCount) {
  if (scheduledCount === 0) return 0;
  return Math.round((takenCount / scheduledCount) * 100);
}

export function getLastNDays(n, endDateStr) {
  const end = strToDate(endDateStr);
  const days = [];
  for (let i = n - 1; i >= 0; i--) {
    const d = new Date(end);
    d.setDate(d.getDate() - i);
    days.push(dateToStr(d));
  }
  return days;
}

export function dayCompletion(doses, events) {
  if (doses.length === 0) return "none";
  let responded = 0;
  let taken = 0;
  for (const dose of doses) {
    const ev = matchDoseToEvent(dose, events);
    if (ev) {
      responded++;
      if (ev.response === "took_it" || ev.response === "not_sure") taken++;
    }
  }
  if (taken === 0) return "none";
  if (taken >= doses.length) return "full";
  return "partial";
}

export function getCalendarMonth(year, month) {
  const firstDay = new Date(year, month, 1);
  const lastDay = new Date(year, month + 1, 0);
  const startWeekday = firstDay.getDay();
  const days = [];
  for (let i = 0; i < startWeekday; i++) days.push(null);
  for (let d = 1; d <= lastDay.getDate(); d++) {
    days.push(new Date(year, month, d));
  }
  const trailing = (7 - (days.length % 7)) % 7;
  for (let i = 0; i < trailing; i++) days.push(null);
  return days;
}

export function monthName(month) {
  return ["January","February","March","April","May","June","July","August","September","October","November","December"][month];
}

export function greeting() {
  const h = new Date().getHours();
  if (h < 12) return "Good morning";
  if (h < 18) return "Good afternoon";
  return "Good evening";
}