import { motion } from "motion/react";

interface PetCardProps {
  petName: string;
  level: number;
  hp?: number;
  maxHp?: number;
  petImage?: string;
  side?: "left" | "right";
  mood?: "happy" | "sad" | "neutral";
}

export function PetCard({ 
  petName, 
  level, 
  hp, 
  maxHp, 
  petImage,
  side = "left",
  mood = "neutral"
}: PetCardProps) {
  const moodEmoji = {
    happy: "😊",
    sad: "😢",
    neutral: "😐"
  };

  return (
    <motion.div
      className="relative p-4 rounded-3xl bg-white/5 backdrop-blur-xl border border-white/10 shadow-2xl"
      initial={{ opacity: 0, x: side === "left" ? -50 : 50 }}
      animate={{ opacity: 1, x: 0 }}
      transition={{ duration: 0.5 }}
    >
      {/* Glow effect */}
      <div className="absolute inset-0 bg-gradient-to-br from-[#8B7FFF]/10 via-transparent to-[#FF6B9D]/10 rounded-3xl" />
      
      <div className="relative z-10 space-y-3">
        {/* Pet Image/Emoji */}
        <div className="flex justify-center">
          <div className="w-16 h-16 rounded-full bg-gradient-to-br from-[#8B7FFF]/20 to-[#FF6B9D]/20 flex items-center justify-center text-4xl backdrop-blur-sm border border-white/10">
            {petImage || moodEmoji[mood]}
          </div>
        </div>
        
        {/* Name and Level */}
        <div className="text-center space-y-1">
          <h3 className="font-semibold text-white">{petName}</h3>
          <p className="text-xs text-white/50">Lv. {level}</p>
        </div>
        
        {/* HP Bar (if provided) */}
        {hp !== undefined && maxHp !== undefined && (
          <div className="space-y-1">
            <div className="flex justify-between text-xs text-white/60">
              <span>HP</span>
              <span>{hp}/{maxHp}</span>
            </div>
            <div className="h-1.5 rounded-full bg-white/10 overflow-hidden">
              <motion.div
                className="h-full bg-gradient-to-r from-[#FF6B9D] to-[#FF8A65] rounded-full"
                initial={{ width: 0 }}
                animate={{ width: `${(hp / maxHp) * 100}%` }}
                transition={{ duration: 0.5 }}
              />
            </div>
          </div>
        )}
      </div>
    </motion.div>
  );
}
