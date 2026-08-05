import { useNavigate } from "react-router-dom";
import { store } from "@/lib/dataStore";
import MedicationForm from "@/components/MedicationForm";
import { ArrowLeft } from "lucide-react";
import toast from "react-hot-toast";

export default function AddMedication() {
  const navigate = useNavigate();

  async function handleSubmit(data) {
    try {
      await store.medications.create(data);
      toast.success("Medication added!");
      navigate("/");
    } catch (e) {
      toast.error("Could not save medication");
    }
  }

  return (
    <div>
      <header className="sticky top-0 bg-slate-50/90 backdrop-blur-md z-10 px-4 py-4 flex items-center gap-3 border-b border-slate-200">
        <button onClick={() => navigate(-1)} className="p-2 -ml-2 text-slate-600">
          <ArrowLeft size={24} />
        </button>
        <h1 className="text-xl font-bold text-slate-800">Add Medication</h1>
      </header>
      <MedicationForm onSubmit={handleSubmit} submitLabel="Save Medication" />
    </div>
  );
}