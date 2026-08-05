import { RESPONSE_META } from "@/lib/doseUtils";

export default function ConfidenceCheck({ open, dose, onResponse, onClose }) {
  if (!open) return null;
  const options = [
    { key: "took_it", emoji: "✅", label: "Took it", sub: "I instilled the drop", color: "bg-green-50 border-green-300 text-green-800" },
    { key: "not_sure", emoji: "🤔", label: "Not sure it went in", sub: "I think I missed", color: "bg-amber-50 border-amber-300 text-amber-800" },
    { key: "snoozed", emoji: "⏰", label: "Snooze 10 min", sub: "I'll do it shortly", color: "bg-blue-50 border-blue-300 text-blue-800" },
    { key: "skipped", emoji: "❌", label: "Skip this dose", sub: "I'll skip for now", color: "bg-rose-50 border-rose-300 text-rose-800" },
  ];
  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/40" onClick={onClose}>
      <div
        className="w-full max-w-md bg-white rounded-t-3xl sm:rounded-3xl p-6 shadow-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="text-center mb-5">
          <p className="text-sm text-slate-400 mb-1">Confidence Check</p>
          <h3 className="text-2xl font-bold text-slate-800">{dose?.medication_name}</h3>
          <p className="text-slate-500 mt-1">
            {dose ? `${dose.eye === "both" ? "Both eyes" : dose.eye === "right" ? "Right eye" : "Left eye"} · ${dose.scheduled_hhmm}` : ""}
          </p>
        </div>
        <div className="grid gap-3">
          {options.map((opt) => (
            <button
              key={opt.key}
              onClick={() => onResponse(opt.key)}
              className={`flex items-center gap-3 p-4 rounded-2xl border-2 active:scale-[0.98] transition-transform ${opt.color}`}
            >
              <span className="text-3xl">{opt.emoji}</span>
              <div className="text-left">
                <p className="font-semibold text-base">{opt.label}</p>
                <p className="text-xs opacity-80">{opt.sub}</p>
              </div>
            </button>
          ))}
        </div>
        <button onClick={onClose} className="w-full mt-4 py-3 text-slate-400 font-medium text-sm">
          Cancel
        </button>
      </div>
    </div>
  );
}