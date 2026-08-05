import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { store } from "@/lib/dataStore";
import CapColorDot from "@/components/CapColorDot";
import MedicationForm from "@/components/MedicationForm";
import { EYE_LABELS, FREQUENCY_LABELS, formatTime, isMedicationActiveOn, todayStr } from "@/lib/doseUtils";
import { generateMedicationICS, downloadICS } from "@/lib/icsGenerator";
import { Plus, Trash2, Pencil, ArrowLeft, CalendarPlus } from "lucide-react";
import toast from "react-hot-toast";

export default function Medications() {
  const navigate = useNavigate();
  const [medications, setMedications] = useState([]);
  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState(null);

  useEffect(() => { load(); }, []);

  async function load() {
    try {
      const meds = await store.medications.list();
      setMedications(meds);
    } catch (e) { console.error(e); }
    setLoading(false);
  }

  async function handleDelete(med) {
    if (!confirm(`Delete ${med.name}?`)) return;
    try {
      await store.medications.delete(med.id);
      toast.success("Medication deleted");
      load();
    } catch (e) { toast.error("Could not delete"); }
  }

  function handleExportMed(med) {
    const ics = generateMedicationICS(med);
    const safe = med.name.replace(/[^a-z0-9]/gi, "-").toLowerCase();
    downloadICS(`${safe}-reminders.ics`, ics);
    toast.success("Calendar file downloaded — open it to add reminders");
  }

  async function handleUpdate(data) {
    try {
      await store.medications.update(editing.id, data);
      toast.success("Medication updated");
      setEditing(null);
      load();
    } catch (e) { toast.error("Could not update"); }
  }

  if (editing) {
    return (
      <div>
        <header className="sticky top-0 bg-slate-50/90 backdrop-blur-md z-10 px-4 py-4 flex items-center gap-3 border-b border-slate-200">
          <button onClick={() => setEditing(null)} className="p-2 -ml-2 text-slate-600"><ArrowLeft size={24} /></button>
          <h1 className="text-xl font-bold text-slate-800">Edit Medication</h1>
        </header>
        <MedicationForm initialValues={editing} onSubmit={handleUpdate} submitLabel="Update Medication" />
      </div>
    );
  }

  const today = todayStr();

  return (
    <div>
      <header className="px-4 pt-6 pb-4 flex items-center justify-between">
        <h1 className="text-2xl font-bold text-slate-800">Medications</h1>
        <button onClick={() => navigate("/add-medication")} className="flex items-center gap-1 px-4 py-2 rounded-xl bg-teal-500 text-white font-medium text-sm">
          <Plus size={18} /> Add
        </button>
      </header>

      {loading ? (
        <div className="flex justify-center py-12"><div className="w-8 h-8 border-4 border-teal-200 border-t-teal-600 rounded-full animate-spin" /></div>
      ) : medications.length === 0 ? (
        <div className="mx-4 rounded-2xl bg-white border border-slate-100 p-8 text-center">
          <p className="text-slate-500 mb-4">No medications yet.</p>
          <button onClick={() => navigate("/add-medication")} className="inline-flex items-center gap-2 px-5 py-3 rounded-xl bg-teal-500 text-white font-medium">
            <Plus size={20} /> Add your first drop
          </button>
        </div>
      ) : (
        <div className="px-4 space-y-3">
          {medications.map(med => {
            const active = isMedicationActiveOn(med, today);
            return (
              <div key={med.id} className={`rounded-2xl bg-white border-2 p-4 ${active ? "border-slate-100" : "border-slate-100 opacity-60"}`}>
                <div className="flex items-start gap-3">
                  <CapColorDot color={med.bottle_cap_color} size={32} />
                  <div className="flex-1 min-w-0">
                    <p className="font-semibold text-slate-800">{med.name}</p>
                    <p className="text-sm text-slate-500">{EYE_LABELS[med.eye]} · {FREQUENCY_LABELS[med.frequency_type]}</p>
                    <p className="text-xs text-slate-400 mt-1">
                      {(med.dose_times || []).map(formatTime).join(" · ")}
                    </p>
                    {!active && <p className="text-xs text-slate-400 mt-1">Inactive</p>}
                  </div>
                  <div className="flex gap-1">
                    <button onClick={() => handleExportMed(med)} className="p-2 text-teal-500" title="Add to Calendar"><CalendarPlus size={18} /></button>
                    <button onClick={() => setEditing(med)} className="p-2 text-slate-400"><Pencil size={18} /></button>
                    <button onClick={() => handleDelete(med)} className="p-2 text-rose-400"><Trash2 size={18} /></button>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}