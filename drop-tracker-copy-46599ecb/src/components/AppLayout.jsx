import { Outlet } from "react-router-dom";
import BottomNav from "@/components/BottomNav";

export default function AppLayout() {
  return (
    <div className="min-h-screen bg-slate-50">
      <main className="max-w-md mx-auto min-h-screen pb-24">
        <Outlet />
      </main>
      <BottomNav />
    </div>
  );
}