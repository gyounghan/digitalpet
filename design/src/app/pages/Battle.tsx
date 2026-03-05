import { useState } from "react";
import { motion, AnimatePresence } from "motion/react";
import { Swords, Zap, Shield } from "lucide-react";
import { Link } from "react-router";
import { PetCard } from "../components/pet/PetCard";
import { PetButton } from "../components/pet/PetButton";

type BattleLog = {
  id: number;
  message: string;
  type: "attack" | "defense" | "info";
};

export function Battle() {
  const [myPetHp, setMyPetHp] = useState(100);
  const [opponentHp, setOpponentHp] = useState(100);
  const [battleLogs, setBattleLogs] = useState<BattleLog[]>([
    { id: 1, message: "Battle started!", type: "info" }
  ]);
  const [turn, setTurn] = useState<"player" | "opponent">("player");

  const addLog = (message: string, type: BattleLog["type"]) => {
    setBattleLogs(prev => [
      ...prev,
      { id: Date.now(), message, type }
    ].slice(-5)); // Keep only last 5 logs
  };

  const handleAttack = () => {
    if (turn !== "player") return;
    
    const damage = Math.floor(Math.random() * 20) + 10;
    setOpponentHp(prev => Math.max(0, prev - damage));
    addLog(`Luna dealt ${damage} damage!`, "attack");
    
    setTurn("opponent");
    
    // Opponent's turn
    setTimeout(() => {
      const opponentDamage = Math.floor(Math.random() * 15) + 8;
      setMyPetHp(prev => Math.max(0, prev - opponentDamage));
      addLog(`Shadow dealt ${opponentDamage} damage!`, "attack");
      setTurn("player");
    }, 1500);
  };

  const handleDefend = () => {
    if (turn !== "player") return;
    
    addLog("Luna is defending!", "defense");
    setTurn("opponent");
    
    setTimeout(() => {
      const reducedDamage = Math.floor(Math.random() * 8) + 3;
      setMyPetHp(prev => Math.max(0, prev - reducedDamage));
      addLog(`Shadow dealt ${reducedDamage} damage (reduced)!`, "attack");
      setTurn("player");
    }, 1500);
  };

  return (
    <div className="min-h-screen bg-[#0F0F1E] dark">
      {/* Background */}
      <div className="fixed inset-0 bg-gradient-to-br from-[#1a1a2e] via-[#0F0F1E] to-[#16213e] -z-10" />
      
      {/* Battle arena glow */}
      <div className="fixed top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-96 h-96 bg-[#FF6B9D]/10 rounded-full blur-[150px] -z-10" />
      
      <div className="max-w-[390px] mx-auto min-h-screen p-6 flex flex-col">
        {/* Header */}
        <div className="text-center mb-8 mt-4">
          <h1 className="text-xl text-white mb-1">Battle Arena</h1>
          <p className="text-xs text-white/40">Turn: {turn === "player" ? "Your" : "Opponent's"}</p>
        </div>

        {/* Battle Cards */}
        <div className="relative mb-12">
          <div className="grid grid-cols-2 gap-4 items-center">
            {/* My Pet */}
            <PetCard
              petName="Luna"
              level={12}
              hp={myPetHp}
              maxHp={100}
              side="left"
              mood={myPetHp > 50 ? "happy" : myPetHp > 20 ? "neutral" : "sad"}
            />

            {/* VS Badge */}
            <div className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 z-20">
              <motion.div
                className="w-16 h-16 rounded-full bg-gradient-to-br from-[#8B7FFF] to-[#FF6B9D] flex items-center justify-center shadow-2xl border-4 border-[#0F0F1E]"
                animate={{ rotate: 360 }}
                transition={{ duration: 20, repeat: Infinity, ease: "linear" }}
              >
                <Swords className="w-8 h-8 text-white" />
              </motion.div>
            </div>

            {/* Opponent */}
            <PetCard
              petName="Shadow"
              level={11}
              hp={opponentHp}
              maxHp={100}
              side="right"
              mood={opponentHp > 50 ? "neutral" : opponentHp > 20 ? "neutral" : "sad"}
            />
          </div>
        </div>

        {/* Battle Log */}
        <motion.div
          className="mb-6 p-4 rounded-3xl bg-white/5 backdrop-blur-xl border border-white/10 h-32 overflow-hidden"
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
        >
          <div className="space-y-2 flex flex-col justify-end h-full">
            <AnimatePresence mode="popLayout">
              {battleLogs.map((log) => (
                <motion.div
                  key={log.id}
                  initial={{ opacity: 0, x: -20 }}
                  animate={{ opacity: 1, x: 0 }}
                  exit={{ opacity: 0, height: 0 }}
                  className={`text-sm px-3 py-1.5 rounded-2xl w-fit ${
                    log.type === "attack"
                      ? "bg-[#FF6B9D]/20 text-[#FF6B9D]"
                      : log.type === "defense"
                      ? "bg-[#5DFDCB]/20 text-[#5DFDCB]"
                      : "bg-white/10 text-white/60"
                  }`}
                >
                  {log.message}
                </motion.div>
              ))}
            </AnimatePresence>
          </div>
        </motion.div>

        {/* Action Buttons */}
        <div className="space-y-3">
          <div className="grid grid-cols-2 gap-3">
            <PetButton
              variant="primary"
              icon={Zap}
              onClick={handleAttack}
              disabled={turn !== "player" || myPetHp === 0 || opponentHp === 0}
            >
              Attack
            </PetButton>
            <PetButton
              variant="secondary"
              icon={Shield}
              onClick={handleDefend}
              disabled={turn !== "player" || myPetHp === 0 || opponentHp === 0}
            >
              Defend
            </PetButton>
          </div>

          {(myPetHp === 0 || opponentHp === 0) && (
            <motion.div
              initial={{ opacity: 0, scale: 0.9 }}
              animate={{ opacity: 1, scale: 1 }}
              className="p-4 rounded-3xl bg-gradient-to-br from-[#8B7FFF]/20 to-[#FF6B9D]/20 backdrop-blur-xl border border-white/20 text-center"
            >
              <p className="text-white font-medium text-lg mb-2">
                {myPetHp === 0 ? "Defeat!" : "Victory!"}
              </p>
              <p className="text-sm text-white/60">
                {myPetHp === 0 ? "Better luck next time!" : "You won the battle!"}
              </p>
            </motion.div>
          )}
        </div>

        {/* Navigation */}
        <div className="flex justify-center gap-2 mt-auto pt-8">
          <Link to="/">
            <div className="w-2 h-2 rounded-full bg-white/20" />
          </Link>
          <Link to="/evolution">
            <div className="w-2 h-2 rounded-full bg-white/20" />
          </Link>
          <Link to="/battle">
            <div className="w-2 h-2 rounded-full bg-[#8B7FFF]" />
          </Link>
          <Link to="/share">
            <div className="w-2 h-2 rounded-full bg-white/20" />
          </Link>
        </div>
      </div>
    </div>
  );
}
