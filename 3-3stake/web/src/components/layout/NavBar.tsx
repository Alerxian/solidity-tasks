"use client";

import Link from "next/link";
import dynamic from "next/dynamic";

const ConnectButton = dynamic(
  () => import("@rainbow-me/rainbowkit").then((mod) => mod.ConnectButton),
  { ssr: false }
);

// const tabs = [
//   { href: "/", label: "Home" },
//   // { href: "/stake", label: "Stake" },
//   // { href: "/withdraw", label: "Withdraw" },
//   // { href: "/claim", label: "Claim" },
// ];

export default function NavBar() {
  // const pathname = usePathname();
  return (
    <header className="sticky top-0 z-20 w-full bg-white/95 backdrop-blur border-b">
      <div className="mx-auto max-w-6xl px-4 h-14 flex items-center justify-between">
        <Link
          href="/"
          className="text-xl font-semibold text-purple-600 hover:opacity-80 transition-opacity"
        >
          MetaNode Stake
        </Link>
        {/* <nav className="flex items-center gap-6">
          {tabs.map((t) => {
            const active = pathname === t.href;
            return (
              <Link
                key={t.href}
                href={t.href}
                className={
                  active
                    ? "text-black font-medium border-b-2 border-purple-600 pb-1"
                    : "text-gray-600 hover:text-black pb-1"
                }
              >
                {t.label}
              </Link>
            );
          })}
        </nav> */}
        <ConnectButton showBalance={false} />
      </div>
    </header>
  );
}
