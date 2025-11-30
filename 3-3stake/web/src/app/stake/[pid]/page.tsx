"use client";
import Stake from "@/components/stake/Stake";
import WithdrawList from "@/components/stake/WithdrawList";
import ClaimList from "@/components/stake/ClaimList";
import { STAKE_ADDRESS } from "@/lib/constants";
import { useConnection } from "wagmi";
import { useParams } from "next/navigation";

export default function StakePidPage() {
  const { address } = useConnection();
  const { pid } = useParams<{ pid: string }>();
  const numPid = Number(pid ?? "0");
  return (
    <main className="min-h-[calc(100vh-56px)] px-8 py-16">
      <div className="mx-auto max-w-5xl">
        <div className="grid gap-6">
          <Stake pid={numPid} stakeAddress={STAKE_ADDRESS} account={address} />
          <ClaimList
            pid={numPid}
            stakeAddress={STAKE_ADDRESS}
            account={address}
          />
          <WithdrawList
            pid={numPid}
            stakeAddress={STAKE_ADDRESS}
            account={address}
          />
        </div>
      </div>
    </main>
  );
}
