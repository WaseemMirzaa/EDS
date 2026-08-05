import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { store } from "@/lib/dataStore";
import { PRESETS } from "@/lib/presets";
import { todayStr } from "@/lib/doseUtils";
import { ArrowLeft, ArrowRight, Check } from "lucide-react";
import toast from "react-hot-toast";

export default function Onboarding() {
  const navigate = useNavigate();
  const [step, setStep] = useState(0);
  const [firstName, setFirstName] = useState("");
  const [wakingStart, setWakingStart] = useState("07:00");
  const [wakingEnd, setWakingEnd] = useState("21:00");
  const [acknowledged, setAcknowledged] = useState(false);
  const [applying, setApplying] = useState(false);

  async function finish(usePreset = null) {
    setApplying(true);
    try {
      await store.user.update({
        first_name: firstName,
        waking_start: wakingStart,
        waking_end: wakingEnd,
        onboarded: true,
        has_seen_disclaimer: true,
      });
      if (usePreset) {
        for (const med of usePreset.medications) {
          await store.medications.create({
            ...med,
            start_date: med.start_date || todayStr(),
            taper_steps: (med.taper_steps || []).map((s, i) => ({
              ...s,
              start_date: s.start_date || todayStr(),
            })),
          });
        }
        toast.success(`${usePreset.label} preset added!`);
      }
      navigate("/");
    } catch (e) {
      console.error(e);
      toast.error("Something went wrong");
    }
    setApplying(false);
  }

  const steps = ["Welcome", "About You", "Quick Start"];

  return (
    <div className="min-h-screen bg-gradient-to-b from-teal-50 to-slate-50 flex flex-col">
      {/* Progress dots */}
      <div className="flex justify-center gap-2 pt-8 pb-4">
        {steps.map((_, i) => (
          <div key={i} className={`h-2 rounded-full transition-all ${i === step ? "w-8 bg-teal-500" : i < step ? "w-2 bg-teal-400" : "w-2 bg-slate-300"}`} />
        ))}
      </div>

      <div className="flex-1 flex flex-col justify-center px-6 max-w-md mx-auto w-full">
        {step === 0 && (
          <div className="text-center">
            <div className="text-6xl mb-6">💧</div>
            <h1 className="text-4xl font-bold text-slate-800 mb-3">Drop Tracker</h1>
            <p className="text-lg text-slate-500 mb-8 leading-relaxed">
              Never wonder "did I take my drop?" again. Track your eye drop schedule with confidence.
            </p>
            <div className="rounded-2xl bg-amber-50 border border-amber-200 p-4 text-left mb-8">
              <p className="text-sm leading-relaxed text-amber-900">
                Drop Tracker is a reminder and tracking tool only. It is not a medical device and does not
                provide medical advice. Always follow your eye doctor's instructions.
              </p>
              <label className="flex items-center gap-2 mt-3 cursor-pointer">
                <input
                  type="checkbox"
                  checked={acknowledged}
                  onChange={e => setAcknowledged(e.target.checked)}
                  className="w-5 h-5 rounded accent-teal-600"
                />
                <span className="text-sm font-medium text-amber-900">I understand</span>
              </label>
            </div>
            <button
              disabled={!acknowledged}
              onClick={() => setStep(1)}
              className="w-full h-14 rounded-2xl bg-teal-500 text-white text-lg font-semibold disabled:opacity-40 flex items-center justify-center gap-2"
            >
              Get Started <ArrowRight size={22} />
            </button>
          </div>
        )}

        {step === 1 && (
          <div>
            <h2 className="text-2xl font-bold text-slate-800 mb-2">Let's personalize</h2>
            <p className="text-slate-500 mb-6">This helps us suggest the right dose times for you.</p>
            <div className="space-y-4 mb-8">
              <label className="block">
                <span className="text-sm font-medium text-slate-600">Your first name</span>
                <input
                  type="text"
                  value={firstName}
                  onChange={e => setFirstName(e.target.value)}
                  className="w-full h-14 mt-1 rounded-xl border-2 border-slate-200 px-4 text-lg"
                  placeholder="e.g. Margaret"
                />
              </label>
              <div>
                <span className="text-sm font-medium text-slate-600">When do you usually wake up and go to bed?</span>
                <div className="flex items-center gap-3 mt-1">
                  <input type="time" value={wakingStart} onChange={e => setWakingStart(e.target.value)} className="flex-1 h-14 rounded-xl border-2 border-slate-200 px-3 text-lg" />
                  <span className="text-slate-400">to</span>
                  <input type="time" value={wakingEnd} onChange={e => setWakingEnd(e.target.value)} className="flex-1 h-14 rounded-xl border-2 border-slate-200 px-3 text-lg" />
                </div>
              </div>
            </div>
            <div className="flex gap-3">
              <button onClick={() => setStep(0)} className="h-14 px-6 rounded-2xl border-2 border-slate-200 text-slate-600 flex items-center gap-1">
                <ArrowLeft size={20} /> Back
              </button>
              <button onClick={() => setStep(2)} className="flex-1 h-14 rounded-2xl bg-teal-500 text-white text-lg font-semibold flex items-center justify-center gap-2">
                Continue <ArrowRight size={22} />
              </button>
            </div>
          </div>
        )}

        {step === 2 && (
          <div>
            <h2 className="text-2xl font-bold text-slate-800 mb-2">Quick start</h2>
            <p className="text-slate-500 mb-6">Just had cataract surgery? Start with a typical post-op regimen you can edit.</p>
            <div className="space-y-3 mb-8">
              {PRESETS.map(preset => (
                <button
                  key={preset.id}
                  disabled={applying}
                  onClick={() => finish(preset)}
                  className="w-full text-left p-5 rounded-2xl bg-white border-2 border-slate-200 hover:border-teal-400 transition"
                >
                  <p className="font-semibold text-slate-800 text-lg">👁️ {preset.label}</p>
                  <p className="text-sm text-slate-500 mt-1">{preset.description}</p>
                  <p className="text-xs text-teal-600 mt-2 font-medium">Includes {preset.medications.length} medications</p>
                </button>
              ))}
              <button
                disabled={applying}
                onClick={() => finish(null)}
                className="w-full text-left p-5 rounded-2xl bg-slate-100 border-2 border-transparent hover:border-slate-300 transition"
              >
                <p className="font-semibold text-slate-700 text-lg">I'll add my own</p>
                <p className="text-sm text-slate-500 mt-1">Skip the preset and add medications manually.</p>
              </button>
            </div>
            <button onClick={() => setStep(1)} className="flex items-center gap-1 text-slate-500">
              <ArrowLeft size={20} /> Back
            </button>
          </div>
        )}
      </div>
      {applying && (
        <div className="fixed inset-0 bg-white/80 flex items-center justify-center">
          <div className="w-8 h-8 border-4 border-teal-200 border-t-teal-600 rounded-full animate-spin" />
        </div>
      )}
    </div>
  );
}