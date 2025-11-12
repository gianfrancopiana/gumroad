import React from "react";

interface BugReportButtonProps {
  onClick: () => void;
}

export function BugReportButton({ onClick }: BugReportButtonProps) {
  return (
    <button
      onClick={onClick}
      className="fixed right-6 bottom-6 z-50 flex items-center gap-2 rounded-full border border-border bg-black px-4 py-2 text-white transition-all hover:scale-105"
      aria-label="Report a bug"
    >
      <span className="text-sm font-semibold">!</span>
      <span className="text-xs" style={{ fontSize: "12px" }}>
        Report bug
      </span>
    </button>
  );
}
