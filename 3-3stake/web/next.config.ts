import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  reactCompiler: true,
  turbopack: {
    root: process.cwd(),
  },
  // 关键：排除服务端渲染时的不兼容包
  serverExternalPackages: [
    "@rainbow-me/rainbowkit",
    "@wagmi/connectors",
    "@walletconnect/ethereum-provider",
    "@walletconnect/utils",
    "pino",
    "thread-stream",
  ],
};

export default nextConfig;
