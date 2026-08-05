import { Shield } from "lucide-react";

export default function DisclaimerBanner() {
  return (
    <div className="mx-4 mt-4 rounded-2xl bg-amber-50 border border-amber-200 p-4">
      <div className="flex gap-3">
        <Shield className="shrink-0 text-amber-600" size={22} />
        <p className="text-sm leading-relaxed text-amber-900">
          Drop Tracker is a reminder and tracking tool only. It is not a medical device and does not
          provide medical advice. Always follow your eye doctor's instructions. If you're unsure
          about your medication, contact your eye care provider or pharmacist.
        </p>
      </div>
    </div>
  );
}