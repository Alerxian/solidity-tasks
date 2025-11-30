"use client";

import { useReadContract, usePublicClient, useWalletClient } from "wagmi";
import { MetaNodeStakeABI } from "@/abi/MetaNodeStake";
import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { formatEther, type Address } from "viem";
import { toast } from "sonner";
import { useState } from "react";

export default function ClaimList({
  pid,
  stakeAddress,
  account,
}: {
  pid: number;
  stakeAddress: Address;
  account?: Address;
}) {
  // 获取用户待领取奖励
  const { data: pending } = useReadContract({
    address: stakeAddress,
    abi: MetaNodeStakeABI,
    functionName: "pendingMetaNode",
    args: [BigInt(pid), account!],
    query: { enabled: Boolean(account) },
  });

  // 获取用户详细信息（包括已领取奖励）
  const { data: userInfo } = useReadContract({
    address: stakeAddress,
    abi: MetaNodeStakeABI,
    functionName: "user",
    args: [BigInt(pid), account!],
    query: { enabled: Boolean(account) },
  });

  const userDetails = userInfo as readonly [bigint, bigint, bigint] | undefined;
  // user returns (stAmount, finishedMetaNode, pendingMetaNode)
  // Note: pendingMetaNode in struct is internal accounting, actual pending is calculated by function pendingMetaNode
  const finishedRewards = userDetails?.[1] ?? 0n;

  const pendingRewards = (pending as bigint) ?? 0n;

  const publicClient = usePublicClient();
  const { data: walletClient } = useWalletClient();
  const [isPending, setIsPending] = useState(false);

  async function claim() {
    if (!walletClient || !publicClient || !account) {
      toast.error("请先连接钱包");
      return;
    }

    if (pendingRewards === 0n) {
      toast.error("暂无奖励可领取");
      return;
    }

    try {
      setIsPending(true);
      const { request } = await publicClient.simulateContract({
        account,
        address: stakeAddress,
        abi: MetaNodeStakeABI,
        functionName: "claim",
        args: [BigInt(pid)],
      });
      const hash = await walletClient.writeContract(request);
      toast.info("交易已提交");
      await publicClient.waitForTransactionReceipt({ hash });
      toast.success("领取成功");
    } catch (e: unknown) {
      const msg =
        e instanceof Error
          ? e.message
          : typeof e === "string"
          ? e
          : JSON.stringify(e);
      console.error(msg);
      toast.error("领取失败");
    } finally {
      setIsPending(false);
    }
  }

  if (!account) return null;

  // 只有当有奖励相关数据时才显示
  // if (pendingRewards === 0n && finishedRewards === 0n) return null;

  return (
    <Card className="bg-white/10 text-white border-white/20 shadow-lg w-2xl mx-auto">
      <CardHeader>
        <CardTitle>收益管理</CardTitle>
        <CardDescription className="text-white/80">
          查看并领取您的质押收益
        </CardDescription>
      </CardHeader>
      <CardContent>
        <div className="grid gap-3">
          <div className="flex justify-between text-sm">
            <span>已领取收益:</span>
            <span>{formatEther(finishedRewards)} META</span>
          </div>
          <div className="flex justify-between text-sm font-medium">
            <span>待领取收益:</span>
            <span className="text-yellow-400">
              {formatEther(pendingRewards)} META
            </span>
          </div>
          <Button
            onClick={claim}
            disabled={isPending || pendingRewards === 0n}
            className="w-full mt-2"
            variant={pendingRewards > 0n ? "default" : "secondary"}
          >
            {isPending ? "领取中..." : "领取收益"}
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}
