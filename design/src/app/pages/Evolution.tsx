import { useState } from "react";
import { motion, AnimatePresence } from "motion/react";
import { ArrowRight, Sparkles, Star } from "lucide-react";
import { Link } from "react-router";
import { PetButton } from "../components/pet/PetButton";

export function Evolution() {
  const [isEvolving, setIsEvolving] = useState(false);
  const [hasEvolved, setHasEvolved] = useState(false);

  const handleEvolve = () => {
    setIsEvolving(true);
    setTimeout(() => {
      setHasEvolved(true);
      setIsEvolving(false);
    }, 2000);
  };

  return (
    <div className="min-h-screen bg-[#0F0F1E] dark">
      {/* Background */}
      <div className="fixed inset-0 bg-gradient-to-br from-[#1a1a2e] via-[#0F0F1E] to-[#16213e] -z-10" />
      
      <div className="max-w-[390px] mx-auto min-h-screen p-6 flex flex-col">
        {/* Header */}
        <div className="text-center mb-12 mt-8">
          <h1 className="text-2xl text-white mb-2">Evolution</h1>
          <p className="text-sm text-white/40">Ready to evolve your pet?</p>
        </div>

        {/* Evolution Display */}
        <div className="flex-1 flex items-center justify-center">
          <div className="relative w-full">
            <div className="flex items-center justify-center gap-8">
              {/* Before */}
              <motion.div
                className="relative"
                animate={isEvolving ? { scale: 0.9, opacity: 0.5 } : {}}
              >
                <div className="w-32 h-32 rounded-3xl bg-gradient-to-br from-white/10 to-white/5 backdrop-blur-xl border border-white/20 flex items-center justify-center shadow-2xl">
                  <span className="text-6xl">🌟</span>
                </div>
                <div className="text-center mt-4">
                  <p className="text-sm text-white/60">Current</p>
                  <p className="text-white font-medium">Luna</p>
                  <p className="text-xs text-white/40">Lv. 12</p>
                </div>
              </motion.div>

              {/* Arrow / Animation */}
              <div className="relative">
                <AnimatePresence mode="wait">
                  {isEvolving ? (
                    <motion.div
                      key="evolving"
                      initial={{ opacity: 0, scale: 0 }}
                      animate={{ opacity: 1, scale: 1, rotate: 360 }}
                      exit={{ opacity: 0, scale: 0 }}
                      transition={{ duration: 0.5, repeat: 3 }}
                      className="w-16 h-16 rounded-full bg-gradient-to-br from-[#8B7FFF] to-[#FF6B9D] flex items-center justify-center"
                    >
                      <Sparkles className="w-8 h-8 text-white" />
                    </motion.div>
                  ) : (
                    <motion.div
                      key="arrow"
                      initial={{ opacity: 0 }}
                      animate={{ opacity: 1 }}
                      className="text-white/40"
                    >
                      <ArrowRight className="w-8 h-8" />
                    </motion.div>
                  )}
                </AnimatePresence>

                {/* Particle effects during evolution */}
                {isEvolving && (
                  <>
                    {[...Array(8)].map((_, i) => (
                      <motion.div
                        key={i}
                        className="absolute w-3 h-3 rounded-full bg-[#5DFDCB]"
                        style={{
                          left: '50%',
                          top: '50%',
                        }}
                        initial={{ opacity: 0, x: 0, y: 0 }}
                        animate={{
                          opacity: [0, 1, 0],
                          x: Math.cos((i * Math.PI) / 4) * 60,
                          y: Math.sin((i * Math.PI) / 4) * 60,
                        }}
                        transition={{
                          duration: 1,
                          repeat: Infinity,
                          ease: "easeOut",
                        }}
                      />
                    ))}
                  </>
                )}
              </div>

              {/* After */}
              <motion.div
                className="relative"
                animate={isEvolving ? { scale: 1.1 } : hasEvolved ? { scale: [1, 1.1, 1] } : {}}
                transition={hasEvolved ? { duration: 0.5 } : {}}
              >
                <div className="w-32 h-32 rounded-3xl bg-gradient-to-br from-white/10 to-white/5 backdrop-blur-xl border border-white/20 flex items-center justify-center shadow-2xl relative overflow-hidden">
                  {hasEvolved && (
                    <div className="absolute inset-0 bg-gradient-to-br from-[#8B7FFF]/20 to-[#FF6B9D]/20 animate-pulse" />
                  )}
                  <span className="text-6xl relative z-10">{hasEvolved ? "✨" : "?"}</span>
                </div>
                <div className="text-center mt-4">
                  <p className="text-sm text-white/60">Next Stage</p>
                  <p className="text-white font-medium">{hasEvolved ? "Celestia" : "???"}</p>
                  <p className="text-xs text-white/40">Lv. 15</p>
                </div>
              </motion.div>
            </div>

            {/* Glow effects */}
            {isEvolving && (
              <>
                <div className="absolute inset-0 bg-gradient-to-br from-[#8B7FFF]/20 to-[#FF6B9D]/20 rounded-full blur-3xl" />
                <motion.div
                  className="absolute inset-0 bg-white/10 rounded-full blur-2xl"
                  animate={{ opacity: [0.2, 0.5, 0.2] }}
                  transition={{ duration: 1, repeat: Infinity }}
                />
              </>
            )}
          </div>
        </div>

        {/* Info Card */}
        <motion.div
          className="mb-6 p-6 rounded-3xl bg-white/5 backdrop-blur-xl border border-white/10"
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
        >
          <div className="flex items-start gap-3 mb-4">
            <div className="w-10 h-10 rounded-2xl bg-[#8B7FFF]/20 flex items-center justify-center">
              <Star className="w-5 h-5 text-[#8B7FFF]" />
            </div>
            <div className="flex-1">
              <h3 className="text-white font-medium mb-1">Evolution Requirements</h3>
              <p className="text-sm text-white/60">Level 15 or higher</p>
            </div>
          </div>
          <div className="space-y-2">
            <div className="flex justify-between text-sm">
              <span className="text-white/60">Current Level</span>
              <span className="text-white">12 / 15</span>
            </div>
            <div className="h-2 rounded-full bg-white/10 overflow-hidden">
              <motion.div
                className="h-full bg-gradient-to-r from-[#8B7FFF] to-[#FF6B9D]"
                initial={{ width: 0 }}
                animate={{ width: "80%" }}
                transition={{ duration: 1, delay: 0.3 }}
              />
            </div>
          </div>
        </motion.div>

        {/* Action Button */}
        <div className="space-y-4">
          <PetButton
            variant="primary"
            icon={Sparkles}
            onClick={handleEvolve}
            disabled={isEvolving}
          >
            {isEvolving ? "Evolving..." : hasEvolved ? "Evolved!" : "Evolve Now"}
          </PetButton>
        </div>

        {/* Navigation */}
        <div className="flex justify-center gap-2 mt-8">
          <Link to="/">
            <div className="w-2 h-2 rounded-full bg-white/20" />
          </Link>
          <Link to="/evolution">
            <div className="w-2 h-2 rounded-full bg-[#8B7FFF]" />
          </Link>
          <Link to="/battle">
            <div className="w-2 h-2 rounded-full bg-white/20" />
          </Link>
          <Link to="/share">
            <div className="w-2 h-2 rounded-full bg-white/20" />
          </Link>
        </div>
      </div>
    </div>
  );
}
