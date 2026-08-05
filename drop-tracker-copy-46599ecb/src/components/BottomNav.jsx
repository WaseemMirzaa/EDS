import { NavLink } from "react-router-dom";
import { Home, Calendar, Pill, Settings } from "lucide-react";

const items = [
  { to: "/", label: "Today", icon: Home },
  { to: "/history", label: "History", icon: Calendar },
  { to: "/medications", label: "Meds", icon: Pill },
  { to: "/settings", label: "Settings", icon: Settings },
];

export default function BottomNav() {
  return (
    <nav className="no-print fixed bottom-0 inset-x-0 z-40 bg-white/95 backdrop-blur-md border-t border-slate-200">
      <div className="max-w-md mx-auto grid grid-cols-4 px-2">
        {items.map(({ to, label, icon: Icon }) => (
          <NavLink
            key={to}
            to={to}
            end={to === "/"}
            className={({ isActive }) =>
              `flex flex-col items-center gap-1 py-3 transition-colors ${
                isActive ? "text-teal-600" : "text-slate-400"
              }`
            }
          >
            <Icon size={24} strokeWidth={2.2} />
            <span className="text-xs font-medium">{label}</span>
          </NavLink>
        ))}
      </div>
    </nav>
  );
}