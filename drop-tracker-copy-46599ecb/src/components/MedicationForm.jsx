import { useState } from "react";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import CapColorDot from "@/components/CapColorDot";
import { CAP_COLORS, FREQUENCY_LABELS, EYE_LABELS, suggestTimes, timesForEveryNHours, todayStr } from "@/lib/doseUtils";
import { Plus, X } from "lucide-react";

const FREQUENCIES = [
  { key: "once_daily", label: "Once daily" },
  { key: "twice_daily", label: "Twice daily" },
  { key: "three_daily", label: "3× daily" },
  { key: "four_daily", label: "4× daily" },
  { key: "every_n_hours", label: "Every N hours" },
  { key: "custom_times", label: "Custom times" },
];

const INSTRUCTIONS = [
  { key: "shake", label: "Shake bottle" },
  { key: "refrigerate", label: "Refrigerate" },
  { key: "wait_5_min", label: "Wait 5 min before next drop" },
  { key: "remove_contacts", label: "Remove contact lenses" },
  { key: "press_tear_duct", label: "Press tear duct after" },
];

export default function MedicationForm({ initialValues, onSubmit, submitLabel = "Save Medication" }) {
  const [form, setForm] = useState({
    name: "",
    bottle_cap_color: "white",
    eye: "both",
    frequency_type: "four_daily",
    frequency_value: 4,
    dose_times: ["07:00", "11:00", "15:00", "19:00"],
    start_date: todayStr(),
    end_date: "",
    ongoing: false,
    category: "other",
    instructions: { shake: false, refrigerate: false, wait_5_min: false, remove_contacts: false, press_tear_duct: false, notes: "" },
    taper_steps: [],
    ...initialValues,
  });

  const set = (key, value) => setForm(f => ({ ...f, [key]: value }));
  const setInstr = (key, value) => setForm(f => ({ ...f, instructions: { ...f.instructions, [key]: value } }));

  function onFrequencyChange(ftype) {
    if (ftype === "every_n_hours") {
      const times = timesForEveryNHours(form.frequency_value || 4, "07:00", "21:00");
      setForm(f => ({ ...f, frequency_type: ftype, dose_times: times }));
    } else if (ftype !== "custom_times") {
      const times = suggestTimes(ftype, "07:00", "21:00");
      setForm(f => ({ ...f, frequency_type: ftype, dose_times: times }));
    } else {
      setForm(f => ({ ...f, frequency_type: ftype }));
    }
  }

  function updateTime(idx, value) {
    setForm(f => ({ ...f, dose_times: f.dose_times.map((t, i) => i === idx ? value : t) }));
  }
  function addTime() {
    setForm(f => ({ ...f, dose_times: [...f.dose_times, "12:00"] }));
  }
  function removeTime(idx) {
    setForm(f => ({ ...f, dose_times: f.dose_times.filter((_, i) => i !== idx) }));
  }
  function onEveryNHoursChange(val) {
    const n = parseInt(val) || 1;
    setForm(f => ({ ...f, frequency_value: n, dose_times: timesForEveryNHours(n, "07:00", "21:00") }));
  }

  function addTaperStep() {
    setForm(f => ({ ...f, taper_steps: [...f.taper_steps, { start_date: f.start_date, frequency_type: "twice_daily", frequency_value: 2, dose_times: suggestTimes("twice_daily", "07:00", "21:00") }] }));
  }
  function updateTaperStep(idx, key, value) {
    setForm(f => ({ ...f, taper_steps: f.taper_steps.map((s, i) => {
      if (i !== idx) return s;
      const updated = { ...s, [key]: value };
      if (key === "frequency_type" && value !== "custom_times" && value !== "every_n_hours") {
        updated.dose_times = suggestTimes(value, "07:00", "21:00");
      }
      return updated;
    }) }));
  }
  function removeTaperStep(idx) {
    setForm(f => ({ ...f, taper_steps: f.taper_steps.filter((_, i) => i !== idx) }));
  }

  function handleSubmit(e) {
    e.preventDefault();
    const data = { ...form };
    if (data.ongoing) data.end_date = null;
    if (!data.start_date) data.start_date = todayStr();
    // Fix taper step start dates if empty
    if (data.taper_steps?.length) {
      data.taper_steps = data.taper_steps.map((s, i) => ({
        ...s,
        start_date: s.start_date || (i === 0 ? data.start_date : todayStr()),
      }));
    }
    onSubmit(data);
  }

  return (
    <form onSubmit={handleSubmit} className="px-4 py-4 space-y-6">
      {/* Name */}
      <div className="space-y-2">
        <Label className="text-base">Medication name</Label>
        <Input
          value={form.name}
          onChange={e => set("name", e.target.value)}
          placeholder="e.g. Pred Forte"
          className="h-14 text-lg rounded-xl"
          required
        />
      </div>

      {/* Cap color */}
      <div className="space-y-2">
        <Label className="text-base">Bottle cap color</Label>
        <div className="grid grid-cols-8 gap-2">
          {Object.entries(CAP_COLORS).map(([key, c]) => (
            <button
              key={key}
              type="button"
              onClick={() => set("bottle_cap_color", key)}
              className={`flex flex-col items-center gap-1 p-1 rounded-xl transition ${form.bottle_cap_color === key ? "ring-2 ring-teal-500 ring-offset-1" : ""}`}
            >
              <CapColorDot color={key} size={28} />
            </button>
          ))}
        </div>
      </div>

      {/* Eye */}
      <div className="space-y-2">
        <Label className="text-base">Which eye?</Label>
        <div className="grid grid-cols-3 gap-2">
          {Object.entries(EYE_LABELS).map(([key, label]) => (
            <button
              key={key}
              type="button"
              onClick={() => set("eye", key)}
              className={`py-3 rounded-xl text-sm font-medium border-2 transition ${form.eye === key ? "bg-teal-500 text-white border-teal-500" : "bg-white text-slate-600 border-slate-200"}`}
            >
              {label}
            </button>
          ))}
        </div>
      </div>

      {/* Frequency */}
      <div className="space-y-2">
        <Label className="text-base">Frequency</Label>
        <div className="grid grid-cols-2 gap-2">
          {FREQUENCIES.map(f => (
            <button
              key={f.key}
              type="button"
              onClick={() => onFrequencyChange(f.key)}
              className={`py-3 rounded-xl text-sm font-medium border-2 transition ${form.frequency_type === f.key ? "bg-teal-500 text-white border-teal-500" : "bg-white text-slate-600 border-slate-200"}`}
            >
              {f.label}
            </button>
          ))}
        </div>
        {form.frequency_type === "every_n_hours" && (
          <div className="flex items-center gap-2 mt-2">
            <span className="text-sm text-slate-600">Every</span>
            <Input
              type="number"
              min="1"
              max="12"
              value={form.frequency_value}
              onChange={e => onEveryNHoursChange(e.target.value)}
              className="w-20 h-10 rounded-lg"
            />
            <span className="text-sm text-slate-600">hours</span>
          </div>
        )}
      </div>

      {/* Dose times */}
      <div className="space-y-2">
        <div className="flex items-center justify-between">
          <Label className="text-base">Dose times</Label>
          <button type="button" onClick={addTime} className="flex items-center gap-1 text-teal-600 text-sm font-medium">
            <Plus size={16} /> Add time
          </button>
        </div>
        <div className="space-y-2">
          {form.dose_times.map((time, idx) => (
            <div key={idx} className="flex items-center gap-2">
              <input
                type="time"
                value={time}
                onChange={e => updateTime(idx, e.target.value)}
                className="flex-1 h-12 rounded-xl border-2 border-slate-200 px-3 text-base"
              />
              {form.dose_times.length > 1 && (
                <button type="button" onClick={() => removeTime(idx)} className="p-3 text-slate-400">
                  <X size={20} />
                </button>
              )}
            </div>
          ))}
        </div>
      </div>

      {/* Dates */}
      <div className="space-y-3">
        <div className="space-y-2">
          <Label className="text-base">Start date</Label>
          <input
            type="date"
            value={form.start_date}
            onChange={e => set("start_date", e.target.value)}
            className="w-full h-12 rounded-xl border-2 border-slate-200 px-3 text-base"
          />
        </div>
        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <Label className="text-base">Ongoing (no end date)</Label>
            <Checkbox checked={form.ongoing} onCheckedChange={c => set("ongoing", c)} />
          </div>
          {!form.ongoing && (
            <div>
              <Label className="text-sm text-slate-500">End date</Label>
              <input
                type="date"
                value={form.end_date || ""}
                onChange={e => set("end_date", e.target.value)}
                className="w-full h-12 rounded-xl border-2 border-slate-200 px-3 text-base"
              />
            </div>
          )}
        </div>
      </div>

      {/* Instructions */}
      <div className="space-y-2">
        <Label className="text-base">Special instructions</Label>
        <div className="space-y-2">
          {INSTRUCTIONS.map(instr => (
            <label key={instr.key} className="flex items-center gap-3 p-3 rounded-xl bg-slate-50 cursor-pointer">
              <Checkbox
                checked={form.instructions[instr.key]}
                onCheckedChange={c => setInstr(instr.key, c)}
              />
              <span className="text-sm text-slate-700">{instr.label}</span>
            </label>
          ))}
        </div>
        <textarea
          value={form.instructions.notes || ""}
          onChange={e => setInstr("notes", e.target.value)}
          placeholder="Additional notes (e.g. 'only in right eye')"
          className="w-full min-h-[60px] rounded-xl border-2 border-slate-200 px-3 py-2 text-sm"
        />
      </div>

      {/* Taper */}
      <div className="space-y-2">
        <div className="flex items-center justify-between">
          <Label className="text-base">Taper schedule (optional)</Label>
          <button type="button" onClick={addTaperStep} className="flex items-center gap-1 text-teal-600 text-sm font-medium">
            <Plus size={16} /> Add step
          </button>
        </div>
        {form.taper_steps.length === 0 && (
          <p className="text-xs text-slate-400">For reducing doses over time (e.g. post-surgery steroids).</p>
        )}
        <div className="space-y-3">
          {form.taper_steps.map((step, idx) => (
            <div key={idx} className="p-3 rounded-xl border-2 border-slate-200 space-y-2">
              <div className="flex items-center justify-between">
                <span className="text-xs font-medium text-slate-500">Step {idx + 1}</span>
                <button type="button" onClick={() => removeTaperStep(idx)} className="text-slate-400 p-1">
                  <X size={16} />
                </button>
              </div>
              <input
                type="date"
                value={step.start_date || ""}
                onChange={e => updateTaperStep(idx, "start_date", e.target.value)}
                className="w-full h-10 rounded-lg border-2 border-slate-200 px-2 text-sm"
              />
              <select
                value={step.frequency_type}
                onChange={e => updateTaperStep(idx, "frequency_type", e.target.value)}
                className="w-full h-10 rounded-lg border-2 border-slate-200 px-2 text-sm"
              >
                {FREQUENCIES.map(f => <option key={f.key} value={f.key}>{f.label}</option>)}
              </select>
              <p className="text-xs text-slate-500">Times: {(step.dose_times || []).join(", ")}</p>
            </div>
          ))}
        </div>
      </div>

      <Button type="submit" className="w-full h-14 text-lg rounded-xl bg-teal-500 hover:bg-teal-600">
        {submitLabel}
      </Button>
    </form>
  );
}