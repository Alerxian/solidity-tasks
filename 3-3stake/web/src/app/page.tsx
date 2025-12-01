"use client";
import { motion } from "framer-motion";
import { useEffect, useState } from "react";
import {
  useConnection,
  useReadContract,
  useSendTransaction,
  useWaitForTransactionReceipt,
} from "wagmi";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { toast } from "sonner";
import { Address, parseEther } from "viem";
import { STAKE_ADDRESS } from "@/lib/constants";
import { MetaNodeStakeABI } from "@/abi/MetaNodeStake";

const containerVariants = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { staggerChildren: 0.1, ease: "easeOut" },
  },
} as const;

const itemVariants = {
  hidden: { y: 20, opacity: 0 },
  visible: {
    y: 0,
    opacity: 1,
    transition: { duration: 0.5, ease: "easeOut" },
  },
} as const;

const cardVariants = {
  hidden: { y: 20, opacity: 0 },
  visible: (i: number) => ({
    y: 0,
    opacity: 1,
    transition: {
      delay: i * 0.1,
      duration: 0.5,
      ease: "easeOut" as const,
    },
  }),
} as const;

import { PoolCard } from "@/components/stake/PoolCard";

export default function Home() {
  const { address } = useConnection();
  // 发送交易钩子
  const {
    sendTransaction,
    isPending,
    data: txHash,
    reset,
  } = useSendTransaction();
  // 等待交易确认钩子
  const { isSuccess, isLoading: isConfirming } = useWaitForTransactionReceipt({
    hash: txHash,
  });
  const [to, setTo] = useState("");
  const [val, setVal] = useState("");
  const [err, setErr] = useState("");

  // 是否可以发送
  const canSend = !!address && !!to && !!val && !isPending && !isConfirming;

  useEffect(() => {
    if (isSuccess) {
      toast.success("ETH 发送成功");
      const timer = window.setTimeout(() => {
        setTo("");
        setVal("");
        reset();
      });

      return () => clearTimeout(timer);
    }
  }, [isSuccess, reset]);

  async function send() {
    if (!address) return;
    setErr("");
    try {
      const value = parseEther(val);
      sendTransaction({
        account: address,
        to: to as Address,
        value,
      });
    } catch (e: unknown) {
      const msg =
        e instanceof Error
          ? e.message
          : typeof e === "string"
          ? e
          : JSON.stringify(e);
      setErr(msg);
      toast.error("发送失败");
    }
  }

  // 获取质押池信息
  /** 质押池信息 */
  const { data: poolLength } = useReadContract({
    address: STAKE_ADDRESS,
    abi: MetaNodeStakeABI,
    functionName: "poolLength",
  });

  return (
    <main className="px-8 py-4 text-white">
      <motion.div
        className="mx-auto max-w-5xl"
        variants={containerVariants}
        initial="hidden"
        animate="visible"
      >
        <motion.h1
          className="text-5xl md:text-6xl font-bold mb-4"
          variants={itemVariants}
        >
          欢迎使用 MetaNode DApp
        </motion.h1>
        <motion.p
          className="text-lg text-white/80 mb-8"
          variants={itemVariants}
        >
          连接钱包，管理您的加密资产，参与质押并获取奖励
        </motion.p>

        <motion.div variants={containerVariants} className="min-w-xl mt-4">
          <motion.h2
            className="text-2xl font-bold mb-4"
            variants={itemVariants}
          >
            质押池列表 ({String(poolLength || 0)})
          </motion.h2>
          <motion.div
            className="grid gap-4 md:grid-cols-2"
            variants={containerVariants}
          >
            {Array.from({ length: Number(poolLength || 0) }).map((_, i) => (
              <motion.div
                key={i}
                custom={i}
                variants={cardVariants}
                initial="hidden"
                animate="visible"
              >
                <PoolCard pid={i} />
              </motion.div>
            ))}
          </motion.div>
        </motion.div>

        <motion.div
          className="max-w-2xl rounded-2xl border border-white/20 bg-white/10 backdrop-blur p-6 mt-4"
          variants={itemVariants}
        >
          <div className="text-xl font-semibold mb-4">已连接钱包</div>
          <div className="grid gap-3">
            <Input
              value={address || ""}
              readOnly
              placeholder="钱包地址"
              className="bg-white/20 text-white placeholder:text-white/70 border-white/30"
            />
          </div>
          <div className="text-xl font-semibold mt-6 mb-3">发送 ETH</div>
          <div className="grid gap-3">
            <Input
              placeholder="收款地址"
              value={to}
              onChange={(e) => setTo(e.target.value)}
              className="bg-white/20 text-white placeholder:text-white/70 border-white/30"
            />
            <Input
              placeholder="发送金额 (ETH)"
              value={val}
              onChange={(e) => setVal(e.target.value)}
              className="bg-white/20 text-white placeholder:text-white/70 border-white/30"
            />
            <Button onClick={send} disabled={!canSend}>
              发送 ETH
            </Button>
            {err && (
              <div className="text-sm bg-destructive/20 border border-destructive text-destructive rounded-md px-3 py-2">
                {err}
              </div>
            )}
          </div>
        </motion.div>
      </motion.div>
    </main>
  );
}
