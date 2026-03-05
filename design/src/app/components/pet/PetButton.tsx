import { motion } from "motion/react";
import { LucideIcon } from "lucide-react";

interface PetButtonProps {
  variant?: "primary" | "secondary";
  icon?: LucideIcon;
  children: React.ReactNode;
  onClick?: () => void;
  disabled?: boolean;
}

export function PetButton({ 
  variant = "primary", 
  icon: Icon, 
  children, 
  onClick,
  disabled = false 
}: PetButtonProps) {
  const baseStyles = "relative px-8 py-4 rounded-3xl font-medium overflow-hidden transition-all disabled:opacity-50 disabled:cursor-not-allowed";
  
  const variantStyles = {
    primary: "bg-gradient-to-br from-[#8B7FFF] to-[#6B5FEF] text-white shadow-lg shadow-[#8B7FFF]/30",
    secondary: "bg-white/5 text-white border border-white/10 backdrop-blur-xl shadow-lg"
  };

  return (
    <motion.button
      className={`${baseStyles} ${variantStyles[variant]} flex items-center justify-center gap-2`}
      onClick={onClick}
      disabled={disabled}
      whileTap={{ scale: disabled ? 1 : 0.95 }}
      whileHover={{ scale: disabled ? 1 : 1.02 }}
      transition={{ type: "spring", stiffness: 400, damping: 17 }}
    >
      {/* Glow effect for primary */}
      {variant === "primary" && (
        <div className="absolute inset-0 bg-gradient-to-t from-white/0 via-white/10 to-white/20 rounded-3xl" />
      )}
      
      {Icon && <Icon className="w-5 h-5 relative z-10" />}
      <span className="relative z-10">{children}</span>
    </motion.button>
  );
}
