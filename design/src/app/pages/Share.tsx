import { motion } from "motion/react";
import { QRCodeSVG } from "qrcode.react";
import { Share2, Download, Copy, Check } from "lucide-react";
import { Link } from "react-router";
import { PetButton } from "../components/pet/PetButton";
import { useState } from "react";

export function Share() {
  const [copied, setCopied] = useState(false);
  const shareUrl = "https://pet.app/luna-12";

  const handleCopy = () => {
    navigator.clipboard.writeText(shareUrl);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="min-h-screen bg-[#0F0F1E] dark">
      {/* Background */}
      <div className="fixed inset-0 bg-gradient-to-br from-[#1a1a2e] via-[#0F0F1E] to-[#16213e] -z-10" />
      
      <div className="max-w-[390px] mx-auto min-h-screen p-6 flex flex-col">
        {/* Header */}
        <div className="text-center mb-12 mt-8">
          <h1 className="text-2xl text-white mb-2">Share Your Pet</h1>
          <p className="text-sm text-white/40">Let others meet your companion</p>
        </div>

        {/* Profile Card */}
        <motion.div
          className="mb-8 p-8 rounded-[32px] bg-gradient-to-br from-white/10 to-white/5 backdrop-blur-xl border border-white/20 shadow-2xl relative overflow-hidden"
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
        >
          {/* Gradient overlay */}
          <div className="absolute inset-0 bg-gradient-to-br from-[#8B7FFF]/10 via-transparent to-[#FF6B9D]/10 pointer-events-none" />
          
          <div className="relative z-10">
            {/* Pet Display */}
            <div className="flex flex-col items-center mb-6">
              <motion.div
                className="w-32 h-32 rounded-full bg-gradient-to-br from-[#8B7FFF]/20 to-[#FF6B9D]/20 flex items-center justify-center mb-4 relative"
                animate={{
                  y: [0, -8, 0],
                }}
                transition={{
                  duration: 2,
                  repeat: Infinity,
                  ease: "easeInOut"
                }}
              >
                <div className="absolute inset-0 bg-gradient-to-br from-[#8B7FFF]/30 to-[#FF6B9D]/30 rounded-full blur-xl" />
                <span className="text-7xl relative z-10">🌟</span>
              </motion.div>
              
              <h2 className="text-2xl text-white font-semibold mb-1">Luna</h2>
              <p className="text-white/50 text-sm mb-4">Level 12 • Happy</p>
              
              {/* Stats */}
              <div className="flex gap-4">
                <div className="text-center">
                  <div className="text-[#FFD93D] font-medium">85%</div>
                  <div className="text-xs text-white/40">Happy</div>
                </div>
                <div className="w-px bg-white/10" />
                <div className="text-center">
                  <div className="text-[#FF8A65] font-medium">75%</div>
                  <div className="text-xs text-white/40">Fed</div>
                </div>
                <div className="w-px bg-white/10" />
                <div className="text-center">
                  <div className="text-[#6BCF7F] font-medium">60%</div>
                  <div className="text-xs text-white/40">Energy</div>
                </div>
              </div>
            </div>

            {/* QR Code */}
            <div className="flex justify-center mb-6">
              <div className="p-4 rounded-3xl bg-white">
                <QRCodeSVG
                  value={shareUrl}
                  size={160}
                  level="H"
                  bgColor="#ffffff"
                  fgColor="#0F0F1E"
                />
              </div>
            </div>

            {/* Share URL */}
            <div className="flex items-center gap-2 p-3 rounded-2xl bg-white/5 border border-white/10">
              <input
                type="text"
                value={shareUrl}
                readOnly
                className="flex-1 bg-transparent text-white/60 text-sm outline-none"
              />
              <motion.button
                onClick={handleCopy}
                className="w-9 h-9 rounded-xl bg-white/10 flex items-center justify-center"
                whileTap={{ scale: 0.95 }}
              >
                {copied ? (
                  <Check className="w-4 h-4 text-[#69F0AE]" />
                ) : (
                  <Copy className="w-4 h-4 text-white/60" />
                )}
              </motion.button>
            </div>
          </div>
        </motion.div>

        {/* Share Actions */}
        <div className="space-y-3 mb-8">
          <PetButton variant="primary" icon={Share2}>
            Share to Friends
          </PetButton>
          <PetButton variant="secondary" icon={Download}>
            Download Card
          </PetButton>
        </div>

        {/* Info */}
        <motion.div
          className="p-4 rounded-2xl bg-[#5DFDCB]/10 border border-[#5DFDCB]/20"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.4 }}
        >
          <p className="text-sm text-[#5DFDCB] text-center">
            Share your pet with friends to unlock special rewards!
          </p>
        </motion.div>

        {/* Navigation */}
        <div className="flex justify-center gap-2 mt-auto pt-8">
          <Link to="/">
            <div className="w-2 h-2 rounded-full bg-white/20" />
          </Link>
          <Link to="/evolution">
            <div className="w-2 h-2 rounded-full bg-white/20" />
          </Link>
          <Link to="/battle">
            <div className="w-2 h-2 rounded-full bg-white/20" />
          </Link>
          <Link to="/share">
            <div className="w-2 h-2 rounded-full bg-[#8B7FFF]" />
          </Link>
        </div>
      </div>
    </div>
  );
}
