"use client";
import { useState } from "react";
import { useReadContract, usePublicClient, useWalletClient } from "wagmi";
import { MetaNodeStakeABI } from "@/abi/MetaNodeStake";
import { ERC20ABI } from "@/abi/ERC20";
import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
} from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { formatEther, parseEther, parseUnits, type Address } from "viem";
import { ZERO_ADDRESS } from "@/lib/constants";
import { toast } from "sonner";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";

type PoolInfo = readonly [
  Address,
  bigint,
  bigint,
  bigint,
  bigint,
  bigint,
  bigint
];

export default function Stake({
  pid,
  stakeAddress,
  account,
}: {
  /** 质押池 ID */
  pid: number;
  /** 质押合约地址 */
  stakeAddress: Address;
  /** 用户地址 */
  account?: Address;
}) {
  /** 质押池信息 */
  const { data: rawInfo } = useReadContract({
    address: stakeAddress,
    abi: MetaNodeStakeABI,
    functionName: "pool",
    args: [BigInt(pid)],
  });

  const info = rawInfo as PoolInfo | undefined;
  const [stToken, stTokenAmount, poolWeight, , , minDeposit, lockedBlocks] =
    info || [];

  const isETHPool = stToken === ZERO_ADDRESS;

  // 获取用户质押金额
  const { data: stakingBal } = useReadContract({
    address: stakeAddress,
    abi: MetaNodeStakeABI,
    functionName: "stakingBalance",
    args: [BigInt(pid), account!],
    query: { enabled: Boolean(account) },
  });

  // 获取质押代币的小数位数 如果是 ETH 质押池则默认 18 位
  const { data: tokenDecimals } = useReadContract({
    address: stToken,
    abi: ERC20ABI,
    functionName: "decimals",
    query: { enabled: Boolean(stToken && !isETHPool) },
  });
  const publicClient = usePublicClient();
  const { data: walletClient } = useWalletClient();

  // 质押金额输入框
  const [amount, setAmount] = useState("");
  const [isPending, setIsPending] = useState(false);
  const [isUnstakeDialogOpen, setIsUnstakeDialogOpen] = useState(false);

  async function deposit() {
    const amt = isETHPool
      ? parseEther(amount || "0")
      : parseUnits(
          amount || "0",
          Number((tokenDecimals as number | undefined) ?? 18)
        );

    if (minDeposit && amt < (minDeposit as bigint)) {
      toast.error("金额低于最小质押");
      return;
    }

    if (!account || !walletClient || !publicClient) {
      toast.error("钱包未连接或网络不可用");
      return;
    }

    try {
      setIsPending(true);
      if (isETHPool) {
        // ETH
        // 模拟交易
        const { request: depositETH } = await publicClient.simulateContract({
          account,
          address: stakeAddress,
          abi: MetaNodeStakeABI,
          functionName: "depositETH",
          args: [BigInt(pid)],
          value: amt,
        });
        const hash = await walletClient.writeContract(depositETH);
        await publicClient.waitForTransactionReceipt({ hash });
        toast.success("交易已确认");
        setAmount("");
        setIsPending(false);
      } else {
        // ERC20 代币
        // Check allowance
        const allowance = (await publicClient.readContract({
          address: stToken as Address,
          abi: ERC20ABI,
          functionName: "allowance",
          args: [account, stakeAddress],
        })) as bigint;

        if (allowance < amt) {
          const { request: prepApprove } = await publicClient.simulateContract({
            account,
            address: stToken as Address,
            abi: ERC20ABI,
            functionName: "approve",
            args: [stakeAddress, amt],
          });
          const approveHash = await walletClient.writeContract(prepApprove);
          await publicClient.waitForTransactionReceipt({ hash: approveHash });
          toast.success("授权成功");
        }

        const { request: prepDeposit } = await publicClient.simulateContract({
          account,
          address: stakeAddress,
          abi: MetaNodeStakeABI,
          functionName: "deposit",
          args: [BigInt(pid), amt],
        });
        const hash = await walletClient.writeContract(prepDeposit);
        await publicClient.waitForTransactionReceipt({ hash });
        toast.success("交易已确认");
        setAmount("");
      }
    } catch (e: unknown) {
      const msg =
        e instanceof Error
          ? e.message
          : typeof e === "string"
          ? e
          : JSON.stringify(e);
      toast.error("质押失败，请重试");
      console.error("质押失败", msg);
    } finally {
      setIsPending(false);
    }
  }

  async function unStake() {
    const amt = isETHPool
      ? parseEther(amount || "0")
      : parseUnits(
          amount || "0",
          Number((tokenDecimals as number | undefined) ?? 18)
        );
    if (!account || !publicClient || !walletClient) {
      toast.error("钱包未连接或网络不可用");
      return;
    }

    setIsPending(true);
    setIsUnstakeDialogOpen(false); // Close dialog
    try {
      const { request } = await publicClient.simulateContract({
        account,
        address: stakeAddress,
        abi: MetaNodeStakeABI,
        functionName: "unStake",
        args: [BigInt(pid), amt],
      });
      const hash = await walletClient.writeContract(request);
      await publicClient.waitForTransactionReceipt({ hash });
      toast.success("交易已确认，资金已进入锁定期");
      setAmount("");
    } catch (e: unknown) {
      const msg =
        e instanceof Error
          ? e.message
          : typeof e === "string"
          ? e
          : JSON.stringify(e);
      toast.error("交易失败");
      console.error("解除质押失败", msg);
    } finally {
      setIsPending(false);
    }
  }

  return (
    <Card className="bg-white/10 text-white border-white/20 shadow-lg w-2xl mx-auto">
      <CardHeader>
        <CardTitle className="text-2xl font-bold">池 #{pid}</CardTitle>
        <CardDescription className="text-white/80">
          <div>质押代币: {isETHPool ? "ETH" : stToken}</div>
          <div>权重: {String(poolWeight || 0)}</div>
          <div>总质押: {formatEther(stTokenAmount || 0n)}</div>
          <div>最小质押: {formatEther(minDeposit || 0n)}</div>
          <div>解锁区块数: {String(lockedBlocks || 0)}</div>
        </CardDescription>
      </CardHeader>
      <CardContent>
        <div className="grid gap-3">
          <div className="text-base">
            我的质押: {formatEther((stakingBal as bigint) || 0n)}
          </div>
          <div className="flex gap-2">
            <Input
              placeholder="数量，例如 1.0"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              className="bg-white/20 text-white placeholder:text-white/70 border-white/30"
            />
            <Button
              onClick={deposit}
              disabled={isPending || !account || !amount}
            >
              质押
            </Button>

            <Dialog
              open={isUnstakeDialogOpen}
              onOpenChange={setIsUnstakeDialogOpen}
            >
              <DialogTrigger asChild>
                <Button
                  variant="destructive"
                  disabled={isPending || !account || !amount}
                >
                  解除质押
                </Button>
              </DialogTrigger>
              <DialogContent className="bg-black/90 border-white/20 text-white">
                <DialogHeader>
                  <DialogTitle>确认解除质押？</DialogTitle>
                  <DialogDescription className="text-white/80">
                    解除质押后，资金将锁定{" "}
                    <span className="font-bold text-red-400">
                      {String(lockedBlocks || 0)}
                    </span>{" "}
                    个区块才能提取。
                    <br />
                    在此期间您将无法获得任何奖励。
                  </DialogDescription>
                </DialogHeader>
                <DialogFooter>
                  <Button
                    variant="outline"
                    onClick={() => setIsUnstakeDialogOpen(false)}
                    className="text-black"
                  >
                    取消
                  </Button>
                  <Button
                    variant="destructive"
                    onClick={unStake}
                    disabled={isPending}
                  >
                    {isPending ? "交易中..." : "确认解除"}
                  </Button>
                </DialogFooter>
              </DialogContent>
            </Dialog>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}
