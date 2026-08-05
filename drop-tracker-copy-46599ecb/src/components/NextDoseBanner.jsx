import { formatTime, EYE_LABELS, getInstructionSummary } from "@/lib/doseUtils";
import CapColorDot from "@/components/CapColorDot";
import { Clock, CheckCircle2 } from "lucide-react";

export default function NextDoseBanner({ nextDose, allDone }) {
  if (allDone) {
    return (
      <div className="mx-4 mt-4 rounded-2xl bg-green-50 border border-green-200 p-4 flex items-center gap-3">
        <CheckCircle2 className="text-green-600 shrink-0" size={28} />
        <div>
          <p className="font-semibold text-green-800">All done for today!</p>
          <p className="text-sm text-green-700">Great work taking care of your eyes. 🎉</p>
        </div>
      </div>
    );
  }
  if (!nextDose) {
    return (
      <div className="mx-4 mt-4 rounded-2xl bg-slate-100 border border-slate-200 p-4 flex items-center gap-3">
        <Clock className="text-slate-500 shrink-0" size={28} />
        <div>
          <p className="font-semibold text-slate-700">No doses scheduled today</p>
          <p className="text-sm text-slate-500">Enjoy your day!</p>
        </div>
      </div>
    );
  }
  const instr = getInstructionSummary(nextDose.instructions)[0];
  const now = new Date();
  const [h, m] = nextDose.scheduled_hhmm.split(":").map(Number);
  const doseTime = new Date();
  doseTime.setHours(h, m, 0, 0);
  const diff = doseTime - now;
  const minsAway = Math.round(diff / 60000);
  let timeLabel;
  if (minsAway < 0) timeLabel = "Due now";
  else if (minsAway < 60) timeLabel = `In ${minsAway} min`;
  else timeLabel = `In ${Math.floor(minsAway / 60)}h ${minsAway % 60}m`;

  return (
    <div className="mx-4 mt-4 rounded-2xl bg-gradient-to-br from-teal-500 to-teal-600 p-5 text-white shadow-lg">
      <div className="flex items-center gap-2 mb-2">
        <Clock size={18} className="opacity-80" />
        <span className="text-sm font-medium opacity-90">{timeLabel}</span>
      </div>
      <div className="flex items-center gap-3">
        <CapColorDot color={nextDose.bottle_cap_color} size={32} />
        <div className="flex-1">
          <p className="text-xl font-bold">{nextDose.medication_name}</p>
          <p className="text-sm opacity-90">
            {formatTime(nextDose.scheduled_hhmm)} · {EYE_LABELS[nextDose.eye]}
          </p>
        </div>
      </div>
      {instr && (
        <div className="mt-3 bg-white/15 rounded-xl px-3 py-2 text-sm">
          💡 {instr}
        </div>
      )}
    </div>
  );
}