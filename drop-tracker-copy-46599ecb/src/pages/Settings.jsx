import { useState, useEffect } from "react";
import { store, isGuest, setGuestMode, setPendingMigration } from "@/lib/dataStore";
import DisclaimerBanner from "@/components/DisclaimerBanner";
import ExportAllCalendarButton from "@/components/ExportAllCalendarButton";
import { ChevronLeft } from "lucide-react";
import toast from "react-hot-toast";
import { useNavigate } from "react-router-dom";

export default function Settings() {
  const navigate = useNavigate();
  const [user, setUser] = useState(null);
  const [firstName, setFirstName] = useState("");
  const [wakingStart, setWakingStart] = useState("07:00");
  const [wakingEnd, setWakingEnd] = useState("21:00");
  const [saving, setSaving] = useState(false);

  useEffect(() => { load(); }, []);

  async function load() {
    try {
      const me = await store.user.get();
      setUser(me);
      setFirstName(me.first_name || me.full_name || "");
      setWakingStart(me.waking_start || "07:00");
      setWakingEnd(me.waking_end || "21:00");
    } catch (e) { console.error(e); }
  }

  async function handleSave() {
    setSaving(true);
    try {
      await store.user.update({ first_name: firstName, waking_start: wakingStart, waking_end: wakingEnd });
      toast.success("Settings saved");
    } catch (e) { toast.error("Could not save"); }
    setSaving(false);
  }

  async function handleLogout() {
    const wasGuest = isGuest();
    await store.logout();
    if (wasGuest) navigate("/welcome");
  }

  function handleCreateAccount() {
    setPendingMigration(true);
    setGuestMode(false);
    navigate("/welcome");
  }

  return (
    <div>
      <header className="px-4 pt-6 pb-4">
        <h1 className="text-2xl font-bold text-slate-800">Settings</h1>
      </header>

      <div className="px-4 space-y-6">
        <div className="space-y-3">
          <label className="block">
            <span className="text-sm font-medium text-slate-600">Your name</span>
            <input
              type="text"
              value={firstName}
              onChange={e => setFirstName(e.target.value)}
              className="w-full h-12 mt-1 rounded-xl border-2 border-slate-200 px-3 text-base"
              placeholder="Your first name"
            />
          </label>
          <div>
            <span className="text-sm font-medium text-slate-600">Waking hours</span>
            <div className="flex items-center gap-2 mt-1">
              <input type="time" value={wakingStart} onChange={e => setWakingStart(e.target.value)} className="flex-1 h-12 rounded-xl border-2 border-slate-200 px-3 text-base" />
              <span className="text-slate-400">to</span>
              <input type="time" value={wakingEnd} onChange={e => setWakingEnd(e.target.value)} className="flex-1 h-12 rounded-xl border-2 border-slate-200 px-3 text-base" />
            </div>
            <p className="text-xs text-slate-400 mt-1">Used to auto-suggest evenly spaced dose times.</p>
          </div>
          <button
            onClick={handleSave}
            disabled={saving}
            className="w-full h-12 rounded-xl bg-teal-500 text-white font-medium disabled:opacity-50"
          >
            {saving ? "Saving..." : "Save Settings"}
          </button>
        </div>

        {isGuest() && (
          <div className="rounded-2xl bg-blue-50 border border-blue-200 p-4">
            <p className="font-semibold text-blue-900 mb-1">Guest mode</p>
            <p className="text-sm text-blue-800 leading-relaxed mb-3">
              Your data is stored only on this device and browser. It will be lost if you clear browser
              data or switch devices. Create an account to save it safely.
            </p>
            <button
              onClick={handleCreateAccount}
              className="w-full h-11 rounded-xl bg-blue-600 text-white font-medium text-sm"
            >
              Create an account / Log in
            </button>
          </div>
        )}

        <DisclaimerBanner />

        <div className="space-y-2">
          <ExportAllCalendarButton className="w-full" label="Add all reminders to Calendar" />
          <button onClick={() => navigate("/onboarding")} className="w-full h-12 rounded-xl border-2 border-slate-200 text-slate-600 font-medium">
            Restart Onboarding
          </button>
          <button onClick={handleLogout} className="w-full h-12 rounded-xl border-2 border-rose-200 text-rose-600 font-medium">
            Log Out
          </button>
        </div>

        <p className="text-center text-xs text-slate-300 pb-4">Drop Tracker v1.0</p>
      </div>
    </div>
  );
}