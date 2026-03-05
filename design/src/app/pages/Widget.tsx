import { motion } from "motion/react";
import { Heart, Apple, Battery } from "lucide-react";
import { Link } from "react-router";

export function Widget() {
  return (
    <div className="min-h-screen bg-[#0F0F1E] dark p-6">
      {/* Background */}
      <div className="fixed inset-0 bg-gradient-to-br from-[#1a1a2e] via-[#0F0F1E] to-[#16213e] -z-10" />
      
      <div className="max-w-[390px] mx-auto">
        <div className="text-center mb-12 mt-8">
          <h1 className="text-2xl text-white mb-2">Home Widget</h1>
          <p className="text-sm text-white/40">Widget preview for your home screen</p>
        </div>

        <div className="space-y-6">
          {/* Small Widget */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.1 }}
          >
            <p className="text-white/60 text-sm mb-3">Small Widget (2x2)</p>
            <div className="w-40 h-40 rounded-[28px] bg-gradient-to-br from-white/10 to-white/5 backdrop-blur-xl border border-white/20 p-4 relative overflow-hidden">
              {/* Background gradient */}
              <div className="absolute inset-0 bg-gradient-to-br from-[#8B7FFF]/10 to-[#FF6B9D]/10" />
              
              <div className="relative z-10 flex flex-col items-center justify-center h-full">
                <div className="text-4xl mb-2">🌟</div>
                <div className="text-white/90 font-medium text-sm">Luna</div>
                <div className="flex gap-1 mt-2">
                  <div className="w-1.5 h-1.5 rounded-full bg-[#FFD93D]" />
                  <div className="w-1.5 h-1.5 rounded-full bg-[#FF8A65]" />
                  <div className="w-1.5 h-1.5 rounded-full bg-[#6BCF7F]" />
                </div>
              </div>
            </div>
          </motion.div>

          {/* Medium Widget */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.2 }}
          >
            <p className="text-white/60 text-sm mb-3">Medium Widget (4x2)</p>
            <div className="w-full h-40 rounded-[28px] bg-gradient-to-br from-white/10 to-white/5 backdrop-blur-xl border border-white/20 p-5 relative overflow-hidden">
              {/* Background gradient */}
              <div className="absolute inset-0 bg-gradient-to-br from-[#8B7FFF]/10 to-[#FF6B9D]/10" />
              
              <div className="relative z-10 flex items-center justify-between h-full">
                {/* Pet */}
                <div className="flex flex-col items-center">
                  <div className="text-5xl mb-2">🌟</div>
                  <div className="text-white/90 font-medium">Luna</div>
                  <div className="text-white/40 text-xs">Lv. 12</div>
                </div>

                {/* Stats */}
                <div className="flex-1 ml-6 space-y-3">
                  <div className="flex items-center gap-2">
                    <Heart className="w-4 h-4 text-[#FFD93D]" />
                    <div className="flex-1 h-1.5 rounded-full bg-white/10">
                      <div className="h-full w-[85%] rounded-full bg-gradient-to-r from-[#FFD93D] to-[#FFC107]" />
                    </div>
                    <span className="text-xs text-white/60 w-8 text-right">85</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <Apple className="w-4 h-4 text-[#FF8A65]" />
                    <div className="flex-1 h-1.5 rounded-full bg-white/10">
                      <div className="h-full w-[75%] rounded-full bg-gradient-to-r from-[#FF8A65] to-[#FF6B4A]" />
                    </div>
                    <span className="text-xs text-white/60 w-8 text-right">75</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <Battery className="w-4 h-4 text-[#6BCF7F]" />
                    <div className="flex-1 h-1.5 rounded-full bg-white/10">
                      <div className="h-full w-[60%] rounded-full bg-gradient-to-r from-[#6BCF7F] to-[#4CAF50]" />
                    </div>
                    <span className="text-xs text-white/60 w-8 text-right">60</span>
                  </div>
                </div>
              </div>
            </div>
          </motion.div>

          {/* Large Widget */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.3 }}
          >
            <p className="text-white/60 text-sm mb-3">Large Widget (4x4)</p>
            <div className="w-full h-80 rounded-[32px] bg-gradient-to-br from-white/10 to-white/5 backdrop-blur-xl border border-white/20 p-6 relative overflow-hidden">
              {/* Background gradient */}
              <div className="absolute inset-0 bg-gradient-to-br from-[#8B7FFF]/10 via-transparent to-[#FF6B9D]/10" />
              
              {/* Ambient glow */}
              <div className="absolute top-1/3 left-1/2 -translate-x-1/2 w-48 h-48 bg-[#8B7FFF]/20 rounded-full blur-[80px]" />
              
              <div className="relative z-10 flex flex-col items-center justify-between h-full">
                {/* Header */}
                <div className="w-full flex justify-between items-center">
                  <div>
                    <div className="text-white font-medium">Luna</div>
                    <div className="text-white/40 text-xs">Level 12</div>
                  </div>
                  <div className="px-3 py-1 rounded-full bg-[#69F0AE]/20 text-[#69F0AE] text-xs">
                    Happy
                  </div>
                </div>

                {/* Pet Display */}
                <motion.div
                  animate={{
                    y: [0, -10, 0],
                  }}
                  transition={{
                    duration: 2,
                    repeat: Infinity,
                    ease: "easeInOut"
                  }}
                  className="relative"
                >
                  <div className="w-32 h-32 rounded-full bg-gradient-to-br from-white/10 to-white/5 flex items-center justify-center border border-white/10">
                    <span className="text-7xl">🌟</span>
                  </div>
                </motion.div>

                {/* Stats */}
                <div className="w-full space-y-2.5">
                  <div className="flex items-center gap-2">
                    <Heart className="w-4 h-4 text-[#FFD93D]" />
                    <div className="flex-1 h-2 rounded-full bg-white/10">
                      <div className="h-full w-[85%] rounded-full bg-gradient-to-r from-[#FFD93D] to-[#FFC107] shadow-lg shadow-[#FFD93D]/40" />
                    </div>
                    <span className="text-sm text-white w-10 text-right">85%</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <Apple className="w-4 h-4 text-[#FF8A65]" />
                    <div className="flex-1 h-2 rounded-full bg-white/10">
                      <div className="h-full w-[75%] rounded-full bg-gradient-to-r from-[#FF8A65] to-[#FF6B4A] shadow-lg shadow-[#FF8A65]/40" />
                    </div>
                    <span className="text-sm text-white w-10 text-right">75%</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <Battery className="w-4 h-4 text-[#6BCF7F]" />
                    <div className="flex-1 h-2 rounded-full bg-white/10">
                      <div className="h-full w-[60%] rounded-full bg-gradient-to-r from-[#6BCF7F] to-[#4CAF50] shadow-lg shadow-[#6BCF7F]/40" />
                    </div>
                    <span className="text-sm text-white w-10 text-right">60%</span>
                  </div>
                </div>
              </div>
            </div>
          </motion.div>
        </div>

        {/* Back Button */}
        <div className="flex justify-center mt-12">
          <Link to="/">
            <motion.button
              className="px-6 py-3 rounded-2xl bg-white/5 backdrop-blur-xl border border-white/10 text-white/60 text-sm"
              whileTap={{ scale: 0.95 }}
            >
              Back to Home
            </motion.button>
          </Link>
        </div>
      </div>
    </div>
  );
}
