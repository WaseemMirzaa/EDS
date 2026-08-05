import { useEffect, useRef } from "react";
import { getInstructionSummary } from "@/lib/doseUtils";

export function useDoseReminders(doses, events, onDue) {
  const notifiedRef = useRef(new Set());
  const onDueRef = useRef(onDue);
  onDueRef.current = onDue;

  useEffect(() => {
    if ("Notification" in window && Notification.permission === "default") {
      Notification.requestPermission().catch(() => {});
    }
  }, []);

  useEffect(() => {
    const checkDue = () => {
      const now = new Date();
      const nowHHMM = `${String(now.getHours()).padStart(2, "0")}:${String(now.getMinutes()).padStart(2, "0")}`;
      for (const dose of doses) {
        const key = `${dose.medication_id}-${dose.scheduled_hhmm}`;
        const responded = events.some(
          (e) => e.medication_id === dose.medication_id && e.scheduled_hhmm === dose.scheduled_hhmm
        );
        if (responded) {
          notifiedRef.current.delete(key);
          continue;
        }
        if (notifiedRef.current.has(key)) continue;
        if (dose.scheduled_hhmm <= nowHHMM) {
          notifiedRef.current.add(key);
          fireNotification(dose);
          onDueRef.current?.(dose);
        }
      }
    };
    checkDue();
    const id = setInterval(checkDue, 30000);
    const onFocus = () => checkDue();
    window.addEventListener("focus", onFocus);
    return () => {
      clearInterval(id);
      window.removeEventListener("focus", onFocus);
    };
  }, [doses, events]);
}

function fireNotification(dose) {
  if (!("Notification" in window) || Notification.permission !== "granted") return;
  const eyeLabel =
    dose.eye === "both" ? "both eyes" : dose.eye === "right" ? "right eye" : "left eye";
  let body = `Time for ${dose.medication_name} — ${eyeLabel}.`;
  const instr = getInstructionSummary(dose.instructions)[0];
  if (instr) body += ` ${instr} first.`;
  try {
    const n = new Notification("Drop Tracker", {
      body,
      tag: `${dose.medication_id}-${dose.scheduled_hhmm}`,
      icon: "/favicon.ico",
    });
    n.onclick = () => {
      window.focus();
      n.close();
    };
  } catch (e) {
    /* notifications not available */
  }
}