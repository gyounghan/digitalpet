import { useState } from "react";
import { motion } from "motion/react";
import { Settings, Menu, Heart, Apple, Battery } from "lucide-react";
import { Link } from "react-router";
import { StatusBar } from "../components/pet/StatusBar";
import { PetButton } from "../components/pet/PetButton";
import { GlassCard } from "../components/pet/GlassCard";

export function Home() {
  const [petStats, setPetStats] = useState({
    name: "Luna",
    level: 12,
    hunger: 75,
    happiness: 85,
    stamina: 60,
    mood: "happy" as const
  });

  const handleFeed = () => {
    setPetStats(prev => ({
      ...prev,
      hunger: Math.min(100, prev.hunger + 20),
      mood: "happy"
    }));
  };

  const handlePlay = () => {
    setPetStats(prev => ({
      ...prev,
      happiness: Math.min(100, prev.happiness + 15),
      stamina: Math.max(0, prev.stamina - 10),
      mood: "happy"
    }));
  };

  const handleSleep = () => {
    setPetStats(prev => ({
      ...prev,
      stamina: Math.min(100, prev.stamina + 30),
      mood: "neutral"
    }));
  };

  const moodEmoji = {
    happy: "🌟",
    sad: "💧",
    neutral: "💤"
  };

  return (
    <div className="min-h-screen bg-[#0F0F1E] dark">
      {/* Background gradient */}
      <div className="fixed inset-0 bg-gradient-to-br from-[#1a1a2e] via-[#0F0F1E] to-[#16213e] -z-10" />
      
      {/* Ambient glow effects */}
      <div className="fixed top-20 left-1/2 -translate-x-1/2 w-96 h-96 bg-[#8B7FFF]/10 rounded-full blur-[120px] -z-10" />
      <div className="fixed bottom-20 right-10 w-64 h-64 bg-[#FF6B9D]/10 rounded-full blur-[100px] -z-10" />
      
      <div className="max-w-[390px] mx-auto min-h-screen p-6 pb-safe flex flex-col">
        {/* Header */}
        <header className="flex items-center justify-between mb-8">
          <Link to="/widget">
            <motion.button
              className="w-10 h-10 rounded-2xl bg-white/5 backdrop-blur-xl border border-white/10 flex items-center justify-center"
              whileTap={{ scale: 0.95 }}
            >
              <Menu className="w-5 h-5 text-white/60" />
            </motion.button>
          </Link>
          
          <div className="text-center">
            <h1 className="text-lg text-white/90">{petStats.name}</h1>
            <p className="text-xs text-white/40">Level {petStats.level}</p>
          </div>
          
          <motion.button
            className="w-10 h-10 rounded-2xl bg-white/5 backdrop-blur-xl border border-white/10 flex items-center justify-center"
            whileTap={{ scale: 0.95 }}
          >
            <Settings className="w-5 h-5 text-white/60" />
          </motion.button>
        </header>

        {/* Pet Display */}
        <div className="flex-1 flex flex-col items-center justify-center mb-8">
          <motion.div
            className="relative"
            animate={{
              y: [0, -10, 0],
            }}
            transition={{
              duration: 2,
              repeat: Infinity,
              ease: "easeInOut"
            }}
          >
            {/* Pet Container with glow */}
            <div className="relative">
              {/* Glow effect */}
              <div className="absolute inset-0 bg-gradient-to-br from-[#8B7FFF]/30 to-[#FF6B9D]/30 rounded-full blur-3xl scale-150" />
              
              {/* Pet */}
              <div className="relative w-48 h-48 rounded-full bg-gradient-to-br from-white/10 to-white/5 backdrop-blur-xl border border-white/20 flex items-center justify-center shadow-2xl">
                <span className="text-8xl">{moodEmoji[petStats.mood]}</span>
              </div>
            </div>

            {/* Floating particles */}
            {[...Array(3)].map((_, i) => (
              <motion.div
                key={i}
                className="absolute w-2 h-2 rounded-full bg-[#5DFDCB]/50"
                style={{
                  left: `${20 + i * 30}%`,
                  top: `${10 + i * 20}%`,
                }}
                animate={{
                  y: [-20, -40, -20],
                  opacity: [0.3, 0.8, 0.3],
                }}
                transition={{
                  duration: 2 + i * 0.5,
                  repeat: Infinity,
                  ease: "easeInOut",
                  delay: i * 0.3,
                }}
              />
            ))}
          </motion.div>
        </div>

        {/* Status Section */}
        <GlassCard className="p-6 mb-6" gradient>
          <div className="space-y-4">
            <StatusBar
              label="Hunger"
              value={petStats.hunger}
              color="hunger"
              icon={<Apple className="w-4 h-4" />}
            />
            <StatusBar
              label="Happiness"
              value={petStats.happiness}
              color="happiness"
              icon={<Heart className="w-4 h-4" />}
            />
            <StatusBar
              label="Stamina"
              value={petStats.stamina}
              color="stamina"
              icon={<Battery className="w-4 h-4" />}
            />
          </div>
        </GlassCard>

        {/* Action Buttons */}
        <div className="grid grid-cols-3 gap-3">
          <PetButton variant="secondary" onClick={handleFeed}>
            Feed
          </PetButton>
          <PetButton variant="primary" onClick={handlePlay}>
            Play
          </PetButton>
          <PetButton variant="secondary" onClick={handleSleep}>
            Sleep
          </PetButton>
        </div>

        {/* Navigation Dots */}
        <div className="flex justify-center gap-2 mt-8">
          <Link to="/">
            <div className="w-2 h-2 rounded-full bg-[#8B7FFF]" />
          </Link>
          <Link to="/evolution">
            <div className="w-2 h-2 rounded-full bg-white/20" />
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
