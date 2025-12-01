"use client";
import { createConfig, http } from "wagmi";
import { injected, walletConnect } from "@wagmi/connectors";
import { sepolia } from "wagmi/chains";
import type { Chain } from "viem";

const localChain: Chain = {
  id: 31337,
  name: "Localhost",
  nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: {
    default: {
      http: [process.env.NEXT_PUBLIC_RPC_URL || "http://localhost:8545"],
    },
  },
} as const;

export const config = createConfig({
  chains: [localChain, sepolia],
  ssr: true,
  // storage: createStorage({
  //   storage: cookieStorage,
  // }),
  connectors: [
    injected(),
    ...(typeof window !== "undefined"
      ? [
          walletConnect({
            projectId: process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID || "",
          }),
        ]
      : []),
  ],
  transports: {
    [localChain.id]: http(
      process.env.NEXT_PUBLIC_RPC_URL || "http://localhost:8545"
    ),
    [sepolia.id]: http(),
  },
});
