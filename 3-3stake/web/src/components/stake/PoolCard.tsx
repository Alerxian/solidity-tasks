"use client";

import { useReadContract } from "wagmi";
import { MetaNodeStakeABI } from "@/abi/MetaNodeStake";
import { ERC20ABI } from "@/abi/ERC20";
import {
  Card,
  CardContent,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { STAKE_ADDRESS, ZERO_ADDRESS } from "@/lib/constants";
import { formatEther, type Address } from "viem";
import Link from "next/link";

type PoolInfo = readonly [
  Address, // stTokenAddress
  bigint, // stTokenAmount
  bigint, // poolWeight
  bigint, // lastRewardBlock
  bigint, // accMetaNodePerST
  bigint, // minDepositAmount
  bigint // unstakeLockedBlocks
];

export function PoolCard({ pid }: { pid: number }) {
  const { data: rawInfo, isLoading } = useReadContract({
    address: STAKE_ADDRESS,
    abi: MetaNodeStakeABI,
    functionName: "pool",
    args: [BigInt(pid)],
  });

  const info = rawInfo as PoolInfo | undefined;
  const [stToken, stTokenAmount, poolWeight, , , minDeposit, lockedBlocks] =
    info || [];

  const isETHPool = stToken === ZERO_ADDRESS;

  // 获取代币符号
  const { data: symbol } = useReadContract({
    address: stToken,
    abi: ERC20ABI,
    functionName: "symbol",
    query: {
      enabled: !!stToken && !isETHPool,
    },
  });

  const tokenSymbol = isETHPool ? "ETH" : symbol || "Token";

  if (isLoading) {
    return (
      <div className="h-60 w-full bg-white/5 animate-pulse rounded-xl border border-white/10" />
    );
  }

  if (!info) return null;

  return (
    <Card className="bg-white/10 text-white border-white/20 transition-all hover:bg-white/15">
      <CardHeader>
        <CardTitle className="flex justify-between items-center">
          <span>Pool #{pid}</span>
          <span className="text-sm bg-primary/20 px-2 py-1 rounded text-white border border-primary/30">
            {String(tokenSymbol)}
          </span>
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-2 text-sm text-white/80">
        <div className="flex justify-between">
          <span>总质押:</span>
          <span className="font-medium text-white">
            {formatEther(stTokenAmount || 0n)} {String(tokenSymbol)}
          </span>
        </div>
        <div className="flex justify-between">
          <span>权重:</span>
          <span className="font-medium text-white">
            {String(poolWeight || 0)}
          </span>
        </div>
        <div className="flex justify-between">
          <span>最小质押:</span>
          <span className="font-medium text-white">
            {formatEther(minDeposit || 0n)} {String(tokenSymbol)}
          </span>
        </div>
        <div className="flex justify-between">
          <span>锁定期:</span>
          <span className="font-medium text-white">
            {String(lockedBlocks || 0)} Blocks
          </span>
        </div>
      </CardContent>
      <CardFooter>
        <Link href={`/stake/${pid}`} className="w-full">
          <Button className="w-full" variant="secondary">
            去质押
          </Button>
        </Link>
      </CardFooter>
    </Card>
  );
}
