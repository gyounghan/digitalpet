import { motion } from "motion/react";

interface GlassCardProps {
  children: React.ReactNode;
  className?: string;
  gradient?: boolean;
}

export function GlassCard({ children, className = "", gradient = false }: GlassCardProps) {
  return (
    <motion.div
      className={`relative rounded-3xl bg-white/5 backdrop-blur-xl border border-white/10 shadow-2xl overflow-hidden ${className}`}
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5 }}
    >
      {gradient && (
        <div className="absolute inset-0 bg-gradient-to-br from-[#8B7FFF]/5 via-transparent to-[#FF6B9D]/5 pointer-events-none" />
      )}
      <div className="relative z-10">
        {children}
      </div>
    </motion.div>
  );
}
