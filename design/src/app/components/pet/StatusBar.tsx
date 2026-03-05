import { motion } from "motion/react";

interface StatusBarProps {
  label: string;
  value: number; // 0-100
  color: "hunger" | "happiness" | "stamina";
  icon?: React.ReactNode;
}

const colorMap = {
  hunger: {
    bg: "bg-[#FF8A65]/20",
    fill: "bg-gradient-to-r from-[#FF8A65] to-[#FF6B4A]",
    glow: "shadow-[#FF8A65]/40"
  },
  happiness: {
    bg: "bg-[#FFD93D]/20",
    fill: "bg-gradient-to-r from-[#FFD93D] to-[#FFC107]",
    glow: "shadow-[#FFD93D]/40"
  },
  stamina: {
    bg: "bg-[#6BCF7F]/20",
    fill: "bg-gradient-to-r from-[#6BCF7F] to-[#4CAF50]",
    glow: "shadow-[#6BCF7F]/40"
  }
};

export function StatusBar({ label, value, color, icon }: StatusBarProps) {
  const colors = colorMap[color];
  
  return (
    <div className="space-y-2">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          {icon && <span className="text-white/60">{icon}</span>}
          <span className="text-sm text-white/60">{label}</span>
        </div>
        <span className="text-sm font-medium text-white">{value}%</span>
      </div>
      
      <div className={`h-2 rounded-full ${colors.bg} overflow-hidden backdrop-blur-sm`}>
        <motion.div
          className={`h-full rounded-full ${colors.fill} shadow-lg ${colors.glow}`}
          initial={{ width: 0 }}
          animate={{ width: `${value}%` }}
          transition={{ duration: 0.8, ease: "easeOut" }}
        />
      </div>
    </div>
  );
}
