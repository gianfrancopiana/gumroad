import React, { useState } from "react";

import { request } from "$app/utils/request";
import { cast } from "ts-safe-cast";
import { Button } from "$app/components/Button";
import { Icon } from "$app/components/Icons";

interface BugReportPanelProps {
  isOpen: boolean;
  onClose: () => void;
  pageUrl: string;
}

export function BugReportPanel({ isOpen, onClose, pageUrl }: BugReportPanelProps) {
  const [description, setDescription] = useState("");
  const [includeSystemInfo, setIncludeSystemInfo] = useState(true);
  const [screenshot, setScreenshot] = useState<File | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [needsClarification, setNeedsClarification] = useState<string | null>(null);

  const handleScreenshotUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file && file.type.startsWith("image/")) {
      setScreenshot(file);
    } else {
      setError("Please select an image file.");
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);
    setError(null);
    setNeedsClarification(null);

    try {
      const formData = new FormData();
      formData.append("description", description);
      formData.append("page_url", pageUrl);

      if (includeSystemInfo) {
        formData.append("browser", navigator.userAgent);
        formData.append("os", navigator.platform);
        formData.append("user_agent", navigator.userAgent);
        formData.append("viewport", `${window.innerWidth}x${window.innerHeight}`);
      }

      if (screenshot) {
        formData.append("screenshot", screenshot);
      }

      const response = await request({
        url: "/bug_reports",
        method: "POST",
        accept: "json",
        data: formData,
      });

      const responseData = cast<{
        success: boolean;
        needs_clarification?: boolean;
        clarification_message?: string;
        error?: string;
      }>(await response.json());

      if (responseData.success) {
        if (responseData.needs_clarification) {
          setNeedsClarification(responseData.clarification_message || "Please provide more details about the issue.");
        } else {
          onClose();
          setDescription("");
          setScreenshot(null);
          alert("Bug report submitted successfully! We'll investigate and update you via email.");
        }
      } else {
        setError(responseData.error || "Failed to submit bug report. Please try again.");
      }
    } catch (err) {
      setError("An error occurred while submitting your bug report. Please try again.");
    } finally {
      setIsSubmitting(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-end">
      <div className="fixed inset-0 bg-black/50" onClick={onClose} />
      <div className="relative z-10 h-full w-full max-w-md bg-background shadow-xl">
        <div className="flex h-full flex-col">
          <div className="flex items-center justify-between border-b p-4">
            <h2 className="text-lg font-semibold">Report a bug</h2>
            <button onClick={onClose} className="text-base" aria-label="Close">
              <Icon name="x" />
            </button>
          </div>

          <form onSubmit={handleSubmit} className="flex flex-1 flex-col overflow-x-hidden overflow-y-auto p-4">
            <div className="mb-4">
              <p className="text-muted-foreground mb-2 text-sm">
                Your bug report will be reviewed and may be posted publicly on GitHub (with sensitive information
                removed).
              </p>
            </div>

            {needsClarification && (
              <div className="mb-4 rounded-md bg-yellow-50 p-3 text-sm text-yellow-800">
                <p className="font-semibold">Please provide more details:</p>
                <p>{needsClarification}</p>
              </div>
            )}

            {error && <div className="mb-4 rounded-md bg-red-50 p-3 text-sm text-red-800">{error}</div>}

            <div className="mb-4">
              <label htmlFor="description" className="mb-2 block text-sm font-medium">
                Describe the bug (required)
              </label>
              <textarea
                id="description"
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                required
                rows={6}
                className="border-input w-full rounded-md border bg-background px-3 py-2 text-sm"
                placeholder="What happened? What did you expect to happen?"
              />
            </div>

            <div className="mb-4">
              <p className="text-muted-foreground mb-3 text-sm">
                A screenshot will help us better understand the issue.
              </p>
              <div>
                <input
                  id="screenshot"
                  type="file"
                  accept="image/*"
                  onChange={handleScreenshotUpload}
                  className="hidden"
                />
                <Button
                  type="button"
                  onClick={() => document.getElementById("screenshot")?.click()}
                  outline
                  className="box-border flex w-full max-w-full items-center justify-center gap-2 py-6 text-base"
                >
                  <Icon name="camera2" className="flex-shrink-0 text-lg" />
                  <span className="truncate">Capture screenshot</span>
                </Button>
              </div>
              {screenshot && <p className="text-muted-foreground mt-2 text-sm">Selected: {screenshot.name}</p>}
            </div>

            <div className="mb-4">
              <label className="flex items-center gap-2">
                <input
                  type="checkbox"
                  checked={includeSystemInfo}
                  onChange={(e) => setIncludeSystemInfo(e.target.checked)}
                  className="border-input rounded"
                />
                <span className="text-sm">Include system info to help us debug</span>
              </label>
            </div>

            <div className="mt-auto flex justify-end gap-2 pt-4">
              <Button onClick={onClose}>Cancel</Button>
              <Button type="submit" color="primary" disabled={isSubmitting || !description.trim()}>
                {isSubmitting ? "Sending..." : "Send report"}
              </Button>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
}
