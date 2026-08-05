import { useNavigate } from "react-router-dom";
import { setGuestMode } from "@/lib/dataStore";
import { Droplet, UserCircle, LogIn, UserPlus } from "lucide-react";

export default function Welcome() {
  const navigate = useNavigate();

  return (
    <div className="min-h-screen bg-gradient-to-b from-teal-50 to-slate-50 flex flex-col items-center justify-center px-6 text-center">
      <div className="text-6xl mb-6">💧</div>
      <h1 className="text-4xl font-bold text-slate-800 mb-3">Drop Tracker</h1>
      <p className="text-lg text-slate-500 mb-10 max-w-sm leading-relaxed">
        Never wonder "did I take my drop?" again. Track your eye drop schedule with confidence.
      </p>

      <div className="w-full max-w-sm space-y-3">
        <button
          onClick={() => {
            setGuestMode(true);
            navigate("/");
          }}
          className="w-full h-14 rounded-2xl bg-teal-500 text-white text-lg font-semibold flex items-center justify-center gap-2"
        >
          <UserCircle size={24} /> Continue as Guest
        </button>
        <button
          onClick={() => navigate("/login")}
          className="w-full h-14 rounded-2xl border-2 border-slate-200 bg-white text-slate-700 text-lg font-semibold flex items-center justify-center gap-2"
        >
          <LogIn size={22} /> Log in
        </button>
        <button
          onClick={() => navigate("/register")}
          className="w-full h-14 rounded-2xl border-2 border-slate-200 bg-white text-slate-700 text-lg font-semibold flex items-center justify-center gap-2"
        >
          <UserPlus size={22} /> Create an account
        </button>
      </div>

      <p className="text-xs text-slate-400 mt-8 max-w-xs leading-relaxed">
        Guest mode stores your data only on this device. You can create an account anytime in Settings to
        keep your data safe.
      </p>
    </div>
  );
}