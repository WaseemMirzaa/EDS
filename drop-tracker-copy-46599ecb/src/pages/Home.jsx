import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { store, isGuest, hasPendingMigration, migrateLocalToServer } from "@/lib/dataStore";
import toast from "react-hot-toast";
import NextDoseBanner from "@/components/NextDoseBanner";
import DoseCard from "@/components/DoseCard";
import ConfidenceCheck from "@/components/ConfidenceCheck";
import DidITakeIt from "@/components/DidITakeIt";
import { getDosesForDate, matchDoseToEvent, todayStr, greeting, getLastNDays } from "@/lib/doseUtils";
import { useDoseReminders } from "@/hooks/useDoseReminders";
import ExportAllCalendarButton from "@/components/ExportAllCalendarButton";
import { CheckCircle2, HelpCircle, Plus } from "lucide-react";

export default function Home() {
  const navigate = useNavigate();
  const [user, setUser] = useState(null);
  const [medications, setMedications] = useState([]);
  const [events, setEvents] = useState([]);
  const [allEvents, setAllEvents] = useState([]);
  const [loading, setLoading] = useState(true);
  const [checkDose, setCheckDose] = useState(null);
  const [didIOpen, setDidIOpen] = useState(false);

  useEffect(() => { loadData(); }, []);

  async function loadData() {
    try {
      if (!isGuest() && hasPendingMigration()) {
        try {
          await migrateLocalToServer();
          toast.success("Your guest data has been moved to your account!");
        } catch (e) {
          console.error(e);
        }
      }
      const me = await store.user.get();
      setUser(me);
      if (!me.onboarded) { navigate("/onboarding"); return; }
      const meds = await store.medications.list();
      setMedications(meds);
      const today = todayStr();
      const todayEvs = await store.doseEvents.filter({ scheduled_date: today });
      setEvents(todayEvs);
      const weekAgo = getLastNDays(7, today)[0];
      const weekEvs = await store.doseEvents.filter({ scheduled_date: { $gte: weekAgo } });
      setAllEvents(weekEvs);
    } catch (e) { console.error(e); }
    setLoading(false);
  }

  const today = todayStr();
  const wakingStart = user?.waking_start || "07:00";
  const wakingEnd = user?.waking_end || "21:00";
  const doses = getDosesForDate(medications, today, wakingStart, wakingEnd);

  useDoseReminders(doses, events, (dose) => { if (!checkDose) setCheckDose(dose); });

  if (loading) {
    return <div className="flex items-center justify-center min-h-screen"><div className="w-8 h-8 border-4 border-teal-200 border-t-teal-600 rounded-full animate-spin" /></div>;
  }
  const doneDoses = doses.filter(d => matchDoseToEvent(d, events));
  const doneCount = doneDoses.length;
  const progress = doses.length > 0 ? Math.round((doneCount / doses.length) * 100) : 0;
  const now = new Date();
  const nowHHMM = `${String(now.getHours()).padStart(2, "0")}:${String(now.getMinutes()).padStart(2, "0")}`;
  const nextDose = doses.find(d => !matchDoseToEvent(d, events) && d.scheduled_hhmm >= nowHHMM);
  const allDone = doses.length > 0 && doneCount === doses.length;

  const notSureThisWeek = allEvents.filter(e => e.response === "not_sure").length;
  const showTipSheet = notSureThisWeek >= 3;

  function timeDiffMin(a, b) {
    const [ah, am] = a.split(":").map(Number);
    const [bh, bm] = b.split(":").map(Number);
    return Math.abs((bh * 60 + bm) - (ah * 60 + am));
  }

  async function handleResponse(response) {
    const dose = checkDose;
    await store.doseEvents.create({
      medication_id: dose.medication_id,
      medication_name: dose.medication_name,
      bottle_cap_color: dose.bottle_cap_color,
      eye: dose.eye,
      scheduled_time: dose.scheduled_time,
      scheduled_date: dose.scheduled_date,
      scheduled_hhmm: dose.scheduled_hhmm,
      response,
      response_time: new Date().toISOString(),
      instruction_flags: dose.instructions,
    });
    setCheckDose(null);
    loadData();
  }

  const firstName = user?.first_name || user?.full_name || "there";

  return (
    <div>
      <header className="px-4 pt-6 pb-2">
        <p className="text-sm text-slate-400">{greeting()},</p>
        <h1 className="text-3xl font-bold text-slate-800">{firstName} 👋</h1>
      </header>

      <NextDoseBanner nextDose={nextDose} allDone={allDone} />

      {doses.length > 0 && (
        <div className="mx-4 mt-4">
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm font-medium text-slate-600">Today's progress</span>
            <span className="text-sm font-bold text-teal-600">{doneCount} of {doses.length} done</span>
          </div>
          <div className="h-3 rounded-full bg-slate-100 overflow-hidden">
            <div className="h-full rounded-full bg-gradient-to-r from-teal-400 to-teal-600 transition-all duration-500" style={{ width: `${progress}%` }} />
          </div>
        </div>
      )}

      <div className="mt-4">
        {doses.length === 0 ? (
          <div className="mx-4 rounded-2xl bg-white border border-slate-100 p-8 text-center">
            <p className="text-slate-500 mb-4">No medications set up yet.</p>
            <button onClick={() => navigate("/add-medication")} className="inline-flex items-center gap-2 px-5 py-3 rounded-xl bg-teal-500 text-white font-medium">
              <Plus size={20} /> Add your first drop
            </button>
          </div>
        ) : (
          doses.map((dose, idx) => (
            <div key={`${dose.medication_id}-${dose.scheduled_hhmm}`}>
              <DoseCard dose={dose} events={events} onCheck={setCheckDose} />
              {idx < doses.length - 1 && timeDiff(dose.scheduled_hhmm, doses[idx + 1].scheduled_hhmm) <= 5 && (dose.instructions?.wait_5_min || doses[idx + 1].instructions?.wait_5_min) && (
                <div className="mx-4 mb-3 -mt-1 px-3 py-2 rounded-lg bg-blue-50 border border-blue-100 text-xs text-blue-700 font-medium">
                  ⏳ Wait 5 minutes between these drops
                </div>
              )}
            </div>
          ))
        )}
      </div>

      {showTipSheet && (
        <div className="mx-4 mt-4 mb-4 rounded-2xl bg-amber-50 border border-amber-200 p-4">
          <p className="font-semibold text-amber-900 mb-1">💡 Instilling drops tips</p>
          <p className="text-sm text-amber-800 leading-relaxed">
            You've marked a few doses as "not sure" this week. Try tilting your head back, pulling down
            the lower lid to create a pocket, and looking up before squeezing. Consider mentioning this at
            your next eye care visit.
          </p>
        </div>
      )}

      {doses.length > 0 && (
        <button
          onClick={() => setDidIOpen(true)}
          className="mx-4 mt-2 mb-4 w-[calc(100%-2rem)] flex items-center justify-center gap-2 py-4 rounded-2xl border-2 border-teal-200 bg-teal-50 text-teal-700 font-semibold"
        >
          <HelpCircle size={22} /> Did I take my drop?
        </button>
      )}

      {doses.length > 0 && (
        <div className="mx-4 mb-4">
          <ExportAllCalendarButton className="w-full" />
        </div>
      )}

      <ConfidenceCheck open={!!checkDose} dose={checkDose} onResponse={handleResponse} onClose={() => setCheckDose(null)} />
      <DidITakeIt open={didIOpen} onClose={() => setDidIOpen(false)} medications={medications} events={events} />
    </div>
  );
}

function timeDiff(a, b) {
  const [ah, am] = a.split(":").map(Number);
  const [bh, bm] = b.split(":").map(Number);
  return Math.abs((bh * 60 + bm) - (ah * 60 + am));
}