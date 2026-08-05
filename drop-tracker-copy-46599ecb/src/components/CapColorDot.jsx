import { CAP_COLORS } from "@/lib/doseUtils";

export default function CapColorDot({ color, size = 24, className = "" }) {
  const c = CAP_COLORS[color] || CAP_COLORS.gray;
  const isLight = color === "white";
  return (
    <span
      className={`inline-flex items-center justify-center rounded-full shrink-0 ${className}`}
      style={{
        width: size,
        height: size,
        background: c.hex,
        boxShadow: `inset 0 0 0 2px ${c.ring}`,
      }}
      aria-label={`${c.label} cap`}
    />
  );
}