"use client";

import { useEffect, useState } from "react";
import { usePublicClient } from "wagmi";
import { MetaNodeStakeABI } from "@/abi/MetaNodeStake";
import { Address, formatEther, Log } from "viem";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { format } from "date-fns";
import { Loader2 } from "lucide-react";

type HistoryLog = {
  type: "Deposit" | "RequestUnStake" | "Withdraw" | "Claim";
  amount: bigint;
  blockNumber: bigint;
  transactionHash: string;
  timestamp?: number;
};

const EVENT_NAMES = {
  Deposit: "质押",
  RequestUnStake: "申请解锁",
  Withdraw: "取回资金",
  Claim: "领取奖励",
};

type LogWithArgs = {
  args: {
    amount?: bigint;
  };
  blockNumber: bigint;
  transactionHash: string;
};

export default function HistoryList({
  pid,
  stakeAddress,
  account,
}: {
  pid: number;
  stakeAddress: Address;
  account?: Address;
}) {
  const publicClient = usePublicClient();
  const [logs, setLogs] = useState<HistoryLog[]>([]);
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    async function fetchLogs() {
      if (!account || !publicClient) return;

      setIsLoading(true);
      try {
        const [depositLogs, requestLogs, withdrawLogs, claimLogs] =
          await Promise.all([
            publicClient.getContractEvents({
              address: stakeAddress,
              abi: MetaNodeStakeABI,
              eventName: "Deposit",
              args: { user: account, pid: BigInt(pid) },
              fromBlock: "earliest",
            }),
            publicClient.getContractEvents({
              address: stakeAddress,
              abi: MetaNodeStakeABI,
              eventName: "RequestUnStake",
              args: { user: account, pid: BigInt(pid) },
              fromBlock: "earliest",
            }),
            publicClient.getContractEvents({
              address: stakeAddress,
              abi: MetaNodeStakeABI,
              eventName: "Withdraw",
              args: { user: account, pid: BigInt(pid) },
              fromBlock: "earliest",
            }),
            publicClient.getContractEvents({
              address: stakeAddress,
              abi: MetaNodeStakeABI,
              eventName: "Claim",
              args: { user: account, pid: BigInt(pid) },
              fromBlock: "earliest",
            }),
          ]);

        const formatLogs = (
          rawLogs: unknown[],
          type: HistoryLog["type"]
        ): HistoryLog[] => {
          return (rawLogs as LogWithArgs[]).map((log) => {
            return {
              type,
              amount: log.args.amount || 0n,
              blockNumber: log.blockNumber,
              transactionHash: log.transactionHash,
            };
          });
        };

        const allLogs = [
          ...formatLogs(depositLogs, "Deposit"),
          ...formatLogs(requestLogs, "RequestUnStake"),
          ...formatLogs(withdrawLogs, "Withdraw"),
          ...formatLogs(claimLogs, "Claim"),
        ].sort((a, b) => Number(b.blockNumber - a.blockNumber));

        // Fetch timestamps for the logs (optional, optimized by block)
        // For simplicity, we might skip precise timestamps if too many,
        // or just fetch for the visible ones.
        // Here we fetch for all unique blocks to show date.
        const uniqueBlocks = Array.from(
          new Set(allLogs.map((l) => l.blockNumber))
        );
        const blockTimes = new Map<bigint, number>();

        await Promise.all(
          uniqueBlocks.map(async (bn) => {
            const block = await publicClient.getBlock({ blockNumber: bn });
            blockTimes.set(bn, Number(block.timestamp));
          })
        );

        const logsWithTime = allLogs.map((l) => ({
          ...l,
          timestamp: blockTimes.get(l.blockNumber),
        }));

        setLogs(logsWithTime);
      } catch (e) {
        console.error("Fetch history failed", e);
      } finally {
        setIsLoading(false);
      }
    }

    fetchLogs();
  }, [account, pid, publicClient, stakeAddress]);

  if (!account) return null;

  return (
    <Card className="w-full border-white/20 bg-white/5 backdrop-blur text-white">
      <CardHeader>
        <CardTitle>历史记录</CardTitle>
        <CardDescription className="text-white/70">
          查看您的所有质押、提取和领奖记录
        </CardDescription>
      </CardHeader>
      <CardContent>
        {isLoading ? (
          <div className="flex justify-center py-8">
            <Loader2 className="h-8 w-8 animate-spin text-white/50" />
          </div>
        ) : logs.length === 0 ? (
          <div className="text-center py-8 text-white/50">暂无记录</div>
        ) : (
          <div className="rounded-md border border-white/10">
            <Table>
              <TableHeader className="bg-white/5">
                <TableRow className="border-white/10 hover:bg-white/5">
                  <TableHead className="text-white/70">类型</TableHead>
                  <TableHead className="text-white/70">金额</TableHead>
                  <TableHead className="text-white/70">时间</TableHead>
                  <TableHead className="text-right text-white/70">
                    区块高度
                  </TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {logs.map((log) => (
                  <TableRow
                    key={log.transactionHash + log.type}
                    className="border-white/10 hover:bg-white/5"
                  >
                    <TableCell className="font-medium">
                      {EVENT_NAMES[log.type]}
                    </TableCell>
                    <TableCell>{formatEther(log.amount)}</TableCell>
                    <TableCell>
                      {log.timestamp
                        ? format(
                            new Date(log.timestamp * 1000),
                            "yyyy-MM-dd HH:mm"
                          )
                        : "-"}
                    </TableCell>
                    <TableCell className="text-right">
                      <a
                        href={`https://etherscan.io/tx/${log.transactionHash}`} // Replace with explorer based on chain
                        target="_blank"
                        rel="noopener noreferrer"
                        className="hover:underline text-blue-300"
                      >
                        {log.blockNumber.toString()}
                      </a>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
