import React, { useState } from "react";

import { BugReportButton } from "./BugReportButton";
import { BugReportPanel } from "./BugReportPanel";

export function BugReportWidget() {
  const [isOpen, setIsOpen] = useState(false);

  return (
    <>
      <BugReportButton onClick={() => setIsOpen(true)} />
      <BugReportPanel
        isOpen={isOpen}
        onClose={() => setIsOpen(false)}
        pageUrl={typeof window !== "undefined" ? window.location.href : ""}
      />
    </>
  );
}
