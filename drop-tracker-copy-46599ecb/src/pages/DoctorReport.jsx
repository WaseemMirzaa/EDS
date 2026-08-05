import { useState, useEffect } from "react";
import { store } from "@/lib/dataStore";
import DisclaimerBanner from "@/components/DisclaimerBanner";
import { getDosesForDate, matchDoseToEvent, todayStr, getLastNDays, calculateAdherence, formatTime } from "@/lib/doseUtils";
import { Printer, ArrowLeft } from "lucide-react";
import { useNavigate } from "react-router-dom";

export default function DoctorReport() {
  const navigate = useNavigate();
  const [user, setUser] = useState(null);
  const [medications, setMedications] = useState([]);
  const [events, setEvents] = useState([]);
  const [loading, setLoading] = useState(true);

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
  const last30 = getLastNDays(30, today);

  function medStats(med) {
    let scheduled = 0, taken = 0, missed = 0, unsure = 0;
    const log = [];
    for (const day of last30) {
      if (!med.start_date || med.start_date > day) continue;
      if (!med.ongoing && med.end_date && med.end_date < day) continue;
      const doses = getDosesForDate([med], day, wakingStart, wakingEnd);
      for (const dose of doses) {
        scheduled++;
        const ev = matchDoseToEvent(dose, events);
        if (ev) {
          if (ev.response === "took_it") taken++;
          else if (ev.response === "not_sure") { unsure++; taken++; }
          else if (ev.response === "skipped") missed++;
          log.push({ day, time: dose.scheduled_hhmm, response: ev.response, response_time: ev.response_time });
        } else if (day < today) {
          missed++;
        }
      }
    }
    return { scheduled, taken, missed, unsure, pct: calculateAdherence(scheduled, taken), log };
  }

  const overall = medications.reduce((acc, m) => {
    const s = medStats(m);
    acc.scheduled += s.scheduled; acc.taken += s.taken;
    return acc;
  }, { scheduled: 0, taken: 0 });

  return (
    <div className="print-area">
      <header className="no-print sticky top-0 bg-slate-50/90 backdrop-blur-md z-10 px-4 py-4 flex items-center gap-3 border-b border-slate-200">
        <button onClick={() => navigate("/history")} className="p-2 -ml-2 text-slate-600"><ArrowLeft size={24} /></button>
        <h1 className="text-xl font-bold text-slate-800 flex-1">Adherence Report</h1>
        <button onClick={() => window.print()} className="flex items-center gap-1 px-4 py-2 rounded-xl bg-teal-500 text-white font-medium text-sm">
          <Printer size={18} /> Print
        </button>
      </header>

      <div className="px-4 py-6">
        {/* Report header */}
        <div className="border-b-2 border-slate-300 pb-4 mb-6">
          <h1 className="text-2xl font-bold text-slate-800">Eye Drop Adherence Report</h1>
          <p className="text-sm text-slate-500 mt-1">
            Patient: {user?.first_name || user?.full_name || "—"} · Generated: {new Date().toLocaleDateString("en-US", { year: "numeric", month: "long", day: "numeric" })}
          </p>
          <p className="text-sm text-slate-500">Reporting period: Last 30 days ({last30[0]} to {today})</p>
          <p className="text-sm font-semibold text-slate-700 mt-2">
            Overall adherence: {calculateAdherence(overall.scheduled, overall.taken)}% ({overall.taken}/{overall.scheduled} doses)
          </p>
        </div>

        {medications.length === 0 ? (
          <p className="text-slate-400">No medications to report.</p>
        ) : (
          <div className="space-y-6">
            {medications.map(med => {
              const s = medStats(med);
              return (
                <div key={med.id} className="border border-slate-200 rounded-xl p-4">
                  <h2 className="text-lg font-bold text-slate-800">{med.name}</h2>
                  <p className="text-sm text-slate-500 mb-3">
                    {med.eye === "both" ? "Both eyes" : med.eye === "right" ? "Right eye" : "Left eye"} · Started {med.start_date || "—"}
                  </p>
                  <div className="grid grid-cols-4 gap-2 text-center mb-3">
                    <div className="bg-slate-50 rounded-lg p-2"><p className="text-xs text-slate-400">Adherence</p><p className="font-bold text-teal-600">{s.pct}%</p></div>
                    <div className="bg-slate-50 rounded-lg p-2"><p className="text-xs text-slate-400">Taken</p><p className="font-bold text-green-600">{s.taken}</p></div>
                    <div className="bg-slate-50 rounded-lg p-2"><p className="text-xs text-slate-400">Missed</p><p className="font-bold text-rose-600">{s.missed}</p></div>
                    <div className="bg-slate-50 rounded-lg p-2"><p className="text-xs text-slate-400">Unsure</p><p className="font-bold text-amber-600">{s.unsure}</p></div>
                  </div>
                  {s.log.length > 0 && (
                    <div className="text-xs text-slate-500 max-h-32 overflow-y-auto">
                      <table className="w-full">
                        <tbody>
                          {s.log.slice(-10).map((entry, i) => (
                            <tr key={i} className="border-b border-slate-50">
                              <td className="py-1">{entry.day} {formatTime(entry.time)}</td>
                              <td className="py-1 text-right capitalize">{entry.response.replace("_", " ")}</td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                      {s.log.length > 10 && <p className="text-center mt-1">...{s.log.length - 10} more entries</p>}
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        )}

        <div className="mt-8 pt-4 border-t border-slate-200">
          <p className="text-xs text-slate-400">
            This report is a record of patient-reported dose responses from the Drop Tracker app. It is not a
            medical device and does not constitute medical advice. Generated by Drop Tracker.
          </p>
        </div>
      </div>
    </div>
  );
}