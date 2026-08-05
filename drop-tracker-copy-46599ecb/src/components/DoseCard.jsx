import CapColorDot from "@/components/CapColorDot";
import { formatTime, EYE_SHORT, getInstructionSummary, RESPONSE_META, matchDoseToEvent } from "@/lib/doseUtils";
import { Check } from "lucide-react";

export default function DoseCard({ dose, events, onCheck }) {
  const event = matchDoseToEvent(dose, events || []);
  const isDone = event && (event.response === "took_it" || event.response === "not_sure" || event.response === "skipped");
  const instructionParts = getInstructionSummary(dose.instructions);
  const primaryInstruction = instructionParts[0];

  return (
    <div
      className={`mx-4 mb-3 rounded-2xl border-2 p-4 transition-all ${
        isDone ? "bg-slate-50 border-slate-200" : "bg-white border-slate-100 shadow-sm"
      }`}
    >
      <div className="flex items-center gap-3">
        <div className="text-right w-20 shrink-0">
          <p className={`text-lg font-bold ${isDone ? "text-slate-400" : "text-slate-800"}`}>
            {formatTime(dose.scheduled_hhmm)}
          </p>
        </div>
        <div className="w-px h-12 bg-slate-200 shrink-0" />
        <CapColorDot color={dose.bottle_cap_color} size={28} />
        <div className="flex-1 min-w-0">
          <p className={`font-semibold text-base truncate ${isDone ? "text-slate-400 line-through" : "text-slate-800"}`}>
            {dose.medication_name}
          </p>
          <div className="flex items-center gap-2 text-sm text-slate-500">
            <span className="inline-flex items-center gap-1 bg-slate-100 px-2 py-0.5 rounded-full text-xs font-medium">
              {EYE_SHORT[dose.eye]}
            </span>
            {primaryInstruction && (
              <span className="text-xs text-teal-600 font-medium truncate">{primaryInstruction}</span>
            )}
          </div>
        </div>
        {event ? (
          <div className="flex flex-col items-center gap-1 shrink-0">
            <span className="text-2xl">{RESPONSE_META[event.response].icon}</span>
            <span className="text-[10px] text-slate-400">{RESPONSE_META[event.response].label}</span>
          </div>
        ) : (
          <button
            onClick={() => onCheck(dose)}
            className="shrink-0 w-14 h-14 rounded-full bg-teal-500 text-white flex items-center justify-center shadow-md active:scale-95 transition-transform"
            aria-label="Check off dose"
          >
            <Check size={28} strokeWidth={3} />
          </button>
        )}
      </div>
    </div>
  );
}