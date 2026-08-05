import { useState } from "react";
import { store } from "@/lib/dataStore";
import { generateAllICS, downloadICS } from "@/lib/icsGenerator";
import { CalendarPlus } from "lucide-react";
import toast from "react-hot-toast";

export default function ExportAllCalendarButton({ className = "", label = "Add all reminders to Calendar" }) {
  const [busy, setBusy] = useState(false);

  async function handle() {
    setBusy(true);
    try {
      const meds = await store.medications.list();
      if (!meds || meds.length === 0) {
        toast.error("No medications to export");
        return;
      }
      const ics = generateAllICS(meds);
      downloadICS("drop-tracker-reminders.ics", ics);
      toast.success("Calendar file downloaded — open it to add reminders");
    } catch (e) {
      toast.error("Could not export calendar");
    }
    setBusy(false);
  }

  return (
    <button
      onClick={handle}
      disabled={busy}
      className={`flex items-center justify-center gap-2 py-3 px-4 rounded-2xl border-2 border-teal-200 bg-teal-50 text-teal-700 font-semibold disabled:opacity-50 ${className}`}
    >
      <CalendarPlus size={20} /> {busy ? "Preparing..." : label}
    </button>
  );
}