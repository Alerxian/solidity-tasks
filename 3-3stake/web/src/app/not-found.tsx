import { Button } from "@/components/ui/button";
import Link from "next/link";

export default function NotFound() {
  return (
    <div className="flex flex-col items-center justify-center min-h-[60vh] text-center px-4">
      <h1 className="text-6xl font-bold text-white mb-4">404</h1>
      <h2 className="text-2xl font-semibold text-white/80 mb-8">页面未找到</h2>
      <p className="text-white/60 mb-8 max-w-md">
        抱歉，您访问的页面不存在或已被移动。
      </p>
      <Link href="/">
        <Button variant="secondary" size="lg">
          返回首页
        </Button>
      </Link>
    </div>
  );
}
