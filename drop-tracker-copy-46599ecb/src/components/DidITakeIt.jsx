import CapColorDot from "@/components/CapColorDot";
import { formatTimeShort, RESPONSE_META, EYE_LABELS } from "@/lib/doseUtils";
import { X } from "lucide-react";

export default function DidITakeIt({ open, onClose, medications, events }) {
  if (!open) return null;
  const recentPerMed = medications.map(med => {
    const medEvents = (events || []).filter(e => e.medication_id === med.id);
    const sorted = [...medEvents].sort((a, b) => (b.response_time || "").localeCompare(a.response_time || ""));
    return { med, lastEvent: sorted[0] };
  });

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/40" onClick={onClose}>
      <div className="w-full max-w-md bg-white rounded-t-3xl sm:rounded-3xl p-6 shadow-2xl" onClick={e => e.stopPropagation()}>
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-xl font-bold text-slate-800">Did I take my drop?</h3>
          <button onClick={onClose} className="p-2 text-slate-400"><X size={20} /></button>
        </div>
        <div className="space-y-3">
          {recentPerMed.map(({ med, lastEvent }) => (
            <div key={med.id} className="flex items-center gap-3 p-3 rounded-xl bg-slate-50">
              <CapColorDot color={med.bottle_cap_color} size={28} />
              <div className="flex-1 min-w-0">
                <p className="font-semibold text-slate-800 truncate">{med.name}</p>
                <p className="text-xs text-slate-500">{EYE_LABELS[med.eye]}</p>
              </div>
              {lastEvent ? (
                <div className="text-right">
                  <span className="text-xl">{RESPONSE_META[lastEvent.response].icon}</span>
                  <p className="text-xs text-slate-500">{formatTimeShort(lastEvent.response_time)}</p>
                </div>
              ) : (
                <p className="text-xs text-slate-400">No record today</p>
              )}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}