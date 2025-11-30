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

export default function WithdrawList({
  pid,
  stakeAddress,
  account,
}: {
  pid: number;
  stakeAddress: Address;
  account?: Address;
}) {
  const { data: rawWithdraw } = useReadContract({
    address: stakeAddress,
    abi: MetaNodeStakeABI,
    functionName: "withdrawAmount",
    args: [BigInt(pid), account!],
    query: { enabled: Boolean(account) },
  });
  const withdrawAmounts = rawWithdraw as readonly [bigint, bigint] | undefined;
  const pendingWithdraw = withdrawAmounts?.[1] ?? 0n;
  const requestingWithdraw = withdrawAmounts?.[0] ?? 0n;

  const publicClient = usePublicClient();
  const { data: walletClient } = useWalletClient();
  const [isPending, setIsPending] = useState(false);

  async function withdraw() {
    if (!walletClient || !publicClient || !account) {
      toast.error("请先连接钱包");
      return;
    }
    if (pendingWithdraw === 0n) {
      toast.error("暂无可提取金额");
      return;
    }

    try {
      setIsPending(true);
      const { request } = await publicClient.simulateContract({
        account,
        address: stakeAddress,
        abi: MetaNodeStakeABI,
        functionName: "withdraw",
        args: [BigInt(pid)],
      });
      const hash = await walletClient.writeContract(request);
      toast.info("交易已提交");
      await publicClient.waitForTransactionReceipt({ hash });
      toast.success("提取成功");
    } catch (e: unknown) {
      const msg =
        e instanceof Error
          ? e.message
          : typeof e === "string"
          ? e
          : JSON.stringify(e);
      console.error(msg);
      toast.error("提取失败");
    } finally {
      setIsPending(false);
    }
  }

  if (!account) return null;
  // 只有当有请求中或可提取金额时才显示
  // if (requestingWithdraw === 0n && pendingWithdraw === 0n) return null;

  return (
    <Card className="bg-white/10 text-white border-white/20 shadow-lg w-2xl mx-auto">
      <CardHeader>
        <CardTitle>提取请求</CardTitle>
        <CardDescription className="text-white/80">
          管理您的解押请求
        </CardDescription>
      </CardHeader>
      <CardContent>
        <div className="grid gap-3">
          <div className="flex justify-between text-sm">
            <span>请求中 (锁定中):</span>
            <span>{formatEther(requestingWithdraw - pendingWithdraw)}</span>
          </div>
          <div className="flex justify-between text-sm font-medium">
            <span>可提取 (已解锁):</span>
            <span className="text-green-400">
              {formatEther(pendingWithdraw)}
            </span>
          </div>
          <Button
            onClick={withdraw}
            disabled={isPending || pendingWithdraw === 0n}
            className="w-full mt-2"
            variant={pendingWithdraw > 0n ? "default" : "secondary"}
          >
            {isPending ? "提取中..." : "提取已解锁资产"}
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}
