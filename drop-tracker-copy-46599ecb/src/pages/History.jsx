import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { store } from "@/lib/dataStore";
import {
  getDosesForDate, matchDoseToEvent, todayStr, dateToStr, strToDate, getLastNDays,
  dayCompletion, getCalendarMonth, monthName, calculateAdherence, formatTime,
  RESPONSE_META, EYE_LABELS, EYE_SHORT,
} from "@/lib/doseUtils";
import { ChevronLeft, ChevronRight, Share2, X } from "lucide-react";

export default function History() {
  const navigate = useNavigate();
  const [user, setUser] = useState(null);
  const [medications, setMedications] = useState([]);
  const [events, setEvents] = useState([]);
  const [loading, setLoading] = useState(true);
  const [calMonth, setCalMonth] = useState(() => { const d = new Date(); return { year: d.getFullYear(), month: d.getMonth() }; });
  const [selectedDay, setSelectedDay] = useState(null);

  useEffect(() => { load(); }, []);

  async function load() {
    try {
      const me = await store.user.get();
      setUser(me);
      const meds = await store.medications.list();
      setMedications(meds);
      const start30 = getLastNDays(30, todayStr())[0];
      const evs = await store.doseEvents.filter({ scheduled_date: { $gte: start30 } });
      setEvents(evs);
    } catch (e) { console.error(e); }
    setLoading(false);
  }

  if (loading) {
    return <div className="flex items-center justify-center min-h-screen"><div className="w-8 h-8 border-4 border-teal-200 border-t-teal-600 rounded-full animate-spin" /></div>;
  }

  const today = todayStr();
  const wakingStart = user?.waking_start || "07:00";
  const wakingEnd = user?.waking_end || "21:00";

  // Adherence for last 7 and 30 days
  const last7 = getLastNDays(7, today);
  const last30 = getLastNDays(30, today);
  function adherenceForRange(days) {
    let scheduled = 0, taken = 0;
    for (const day of days) {
      const doses = getDosesForDate(medications, day, wakingStart, wakingEnd);
      scheduled += doses.length;
      for (const dose of doses) {
        const ev = matchDoseToEvent(dose, events);
        if (ev && (ev.response === "took_it" || ev.response === "not_sure")) taken++;
      }
    }
    return { pct: calculateAdherence(scheduled, taken), taken, scheduled };
  }
  const a7 = adherenceForRange(last7);
  const a30 = adherenceForRange(last30);

  // Streak
  function calcStreak() {
    let streak = 0;
    for (let i = 0; i < last30.length; i++) {
      const day = last30[last30.length - 1 - i];
      const doses = getDosesForDate(medications, day, wakingStart, wakingEnd);
      if (doses.length === 0) continue;
      const completion = dayCompletion(doses, events);
      if (completion === "full") streak++;
      else if (day === today) continue;
      else break;
    }
    return streak;
  }
  const streak = calcStreak();

  // Calendar
  const calDays = getCalendarMonth(calMonth.year, calMonth.month);
  function dayColor(day) {
    if (!day) return "";
    const ds = dateToStr(day);
    if (ds > today) return "bg-slate-50 text-slate-300";
    const doses = getDosesForDate(medications, ds, wakingStart, wakingEnd);
    if (doses.length === 0) return "bg-slate-50 text-slate-400";
    const completion = dayCompletion(doses, events);
    if (completion === "full") return "bg-green-100 text-green-800 border border-green-300";
    if (completion === "partial") return "bg-amber-100 text-amber-800 border border-amber-300";
    return "bg-rose-100 text-rose-700 border border-rose-200";
  }

  function prevMonth() {
    setCalMonth(m => m.month === 0 ? { year: m.year - 1, month: 11 } : { year: m.year, month: m.month - 1 });
  }
  function nextMonth() {
    setCalMonth(m => m.month === 11 ? { year: m.year + 1, month: 0 } : { year: m.year, month: m.month + 1 });
  }

  const selectedDoses = selectedDay ? getDosesForDate(medications, selectedDay, wakingStart, wakingEnd) : [];

  return (
    <div>
      <header className="px-4 pt-6 pb-4 flex items-center justify-between">
        <h1 className="text-2xl font-bold text-slate-800">History</h1>
        <button onClick={() => navigate("/doctor-report")} className="flex items-center gap-1 px-3 py-2 rounded-xl bg-teal-500 text-white font-medium text-sm">
          <Share2 size={16} /> Doctor Report
        </button>
      </header>

      {/* Stats */}
      <div className="px-4 grid grid-cols-3 gap-3 mb-4">
        <StatCard label="7-day" value={`${a7.pct}%`} sub={`${a7.taken}/${a7.scheduled}`} />
        <StatCard label="30-day" value={`${a30.pct}%`} sub={`${a30.taken}/${a30.scheduled}`} />
        <StatCard label="Streak" value={`${streak} 🔥`} sub="perfect days" />
      </div>

      {/* Calendar */}
      <div className="mx-4 rounded-2xl bg-white border border-slate-100 p-4 mb-4">
        <div className="flex items-center justify-between mb-4">
          <button onClick={prevMonth} className="p-2 text-slate-500"><ChevronLeft size={20} /></button>
          <h2 className="font-semibold text-slate-800">{monthName(calMonth.month)} {calMonth.year}</h2>
          <button onClick={nextMonth} className="p-2 text-slate-500"><ChevronRight size={20} /></button>
        </div>
        <div className="grid grid-cols-7 gap-1 mb-2">
          {["S","M","T","W","T","F","S"].map((d, i) => <div key={i} className="text-center text-xs text-slate-400 font-medium">{d}</div>)}
        </div>
        <div className="grid grid-cols-7 gap-1">
          {calDays.map((day, i) => {
            if (!day) return <div key={i} />;
            const ds = dateToStr(day);
            return (
              <button
                key={i}
                onClick={() => setSelectedDay(ds)}
                className={`aspect-square rounded-lg flex items-center justify-center text-sm font-medium ${dayColor(day)} ${ds === selectedDay ? "ring-2 ring-teal-500" : ""}`}
              >
                {day.getDate()}
              </button>
            );
          })}
        </div>
        <div className="flex gap-3 mt-4 text-xs text-slate-500">
          <span className="flex items-center gap-1"><span className="w-3 h-3 rounded bg-green-100 border border-green-300" /> All doses</span>
          <span className="flex items-center gap-1"><span className="w-3 h-3 rounded bg-amber-100 border border-amber-300" /> Some</span>
          <span className="flex items-center gap-1"><span className="w-3 h-3 rounded bg-rose-100 border border-rose-200" /> None</span>
        </div>
      </div>

      {/* Day detail */}
      {selectedDay && (
        <div className="mx-4 mb-4 rounded-2xl bg-white border border-slate-100 p-4">
          <div className="flex items-center justify-between mb-3">
            <h3 className="font-semibold text-slate-800">{strToDate(selectedDay).toLocaleDateString("en-US", { weekday: "long", month: "long", day: "numeric" })}</h3>
            <button onClick={() => setSelectedDay(null)} className="p-1 text-slate-400"><X size={18} /></button>
          </div>
          {selectedDoses.length === 0 ? (
            <p className="text-sm text-slate-400">No doses scheduled.</p>
          ) : (
            <div className="space-y-2">
              {selectedDoses.map((dose, i) => {
                const ev = matchDoseToEvent(dose, events);
                return (
                  <div key={i} className="flex items-center gap-3 py-2 border-b border-slate-50 last:border-0">
                    <span className="text-sm text-slate-500 w-20">{formatTime(dose.scheduled_hhmm)}</span>
                    <div className="flex-1">
                      <p className="text-sm font-medium text-slate-700">{dose.medication_name}</p>
                      <p className="text-xs text-slate-400">{EYE_LABELS[dose.eye]}</p>
                    </div>
                    {ev ? (
                      <div className="text-right">
                        <span className="text-lg">{RESPONSE_META[ev.response].icon}</span>
                        <p className="text-xs text-slate-400">{new Date(ev.response_time).toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" })}</p>
                      </div>
                    ) : (
                      <span className="text-xs text-slate-300">—</span>
                    )}
                  </div>
                );
              })}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

function StatCard({ label, value, sub }) {
  return (
    <div className="rounded-2xl bg-white border border-slate-100 p-3 text-center">
      <p className="text-xs text-slate-400 font-medium">{label}</p>
      <p className="text-2xl font-bold text-slate-800">{value}</p>
      <p className="text-xs text-slate-400">{sub}</p>
    </div>
  );
}