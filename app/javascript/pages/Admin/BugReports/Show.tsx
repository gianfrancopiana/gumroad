import { router, usePage } from "@inertiajs/react";
import React, { useState } from "react";
import { cast } from "ts-safe-cast";

type BugReportDetail = {
  id: string;
  title: string | null;
  description: string;
  sanitized_description: string | null;
  status: string;
  category: string | null;
  severity: string | null;
  quality_score: number | null;
  user_type: string;
  page_url: string;
  github_issue_url: string | null;
  github_issue_number: string | null;
  created_at: string;
  validation_result: Record<string, unknown> | null;
  technical_context: Record<string, unknown> | null;
  blur_metadata: Record<string, unknown> | null;
  internal_notes: string | null;
  screenshot_original_url: string | null;
  screenshot_sanitized_url: string | null;
  console_logs_url: string | null;
  user: {
    id: string;
    email: string;
    name: string;
  } | null;
};

type PageProps = {
  bug_report: BugReportDetail;
};

export default function AdminBugReportsShow() {
  const pageProps = usePage().props;
  const bug_report = cast<PageProps>(pageProps).bug_report;
  const [status, setStatus] = useState(bug_report.status);
  const [internalNotes, setInternalNotes] = useState(bug_report.internal_notes || "");
  const [isSaving, setIsSaving] = useState(false);

  const handleUpdate = async () => {
    setIsSaving(true);
    try {
      await router.put(`/admin/bug_reports/${bug_report.id}`, {
        bug_report: {
          status,
          internal_notes: internalNotes
        }
      });
    } catch (error) {
      console.error("Failed to update bug report:", error);
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <section>
      <div className="mb-4">
        <a href="/admin/bug_reports" className="text-primary hover:underline">
          ← Back to bug reports
        </a>
      </div>

      <div className="mb-6">
        <p className="text-sm text-muted-foreground">ID: {bug_report.id}</p>
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <div className="space-y-4">
          <div>
            <h2 className="mb-2 text-lg font-semibold">Description</h2>
            <div className="rounded-md border border-input bg-background p-4">
              <p className="whitespace-pre-wrap">{bug_report.description}</p>
            </div>
          </div>

          {bug_report.sanitized_description && bug_report.sanitized_description !== bug_report.description && (
            <div>
              <h2 className="mb-2 text-lg font-semibold">Sanitized Description</h2>
              <div className="rounded-md border border-input bg-background p-4">
                <p className="whitespace-pre-wrap">{bug_report.sanitized_description}</p>
              </div>
            </div>
          )}

          <div>
            <h2 className="mb-2 text-lg font-semibold">Status & Metadata</h2>
            <div className="space-y-2 rounded-md border border-input bg-background p-4">
              <div className="flex items-center justify-between">
                <span className="text-sm font-medium">Status:</span>
                <select
                  value={status}
                  onChange={(e) => setStatus(e.target.value)}
                  className="rounded-md border border-input bg-background px-2 py-1 text-sm"
                >
                  <option value="pending">Pending</option>
                  <option value="validated">Validated</option>
                  <option value="rejected">Rejected</option>
                  <option value="needs_clarification">Needs Clarification</option>
                  <option value="github_created">GitHub Created</option>
                  <option value="resolved">Resolved</option>
                  <option value="duplicate">Duplicate</option>
                </select>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm font-medium">Category:</span>
                <span className="text-sm">{bug_report.category || "-"}</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm font-medium">Severity:</span>
                <span className="text-sm">{bug_report.severity || "-"}</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm font-medium">Quality Score:</span>
                <span className="text-sm">{bug_report.quality_score ? `${bug_report.quality_score}/100` : "-"}</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm font-medium">User Type:</span>
                <span className="text-sm">{bug_report.user_type}</span>
              </div>
              {bug_report.github_issue_url && (
                <div className="flex items-center justify-between">
                  <span className="text-sm font-medium">GitHub Issue:</span>
                  <a
                    href={bug_report.github_issue_url}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-sm text-primary hover:underline"
                  >
                    #{bug_report.github_issue_number}
                  </a>
                </div>
              )}
            </div>
          </div>

          <div>
            <h2 className="mb-2 text-lg font-semibold">Internal Notes</h2>
            <textarea
              value={internalNotes}
              onChange={(e) => setInternalNotes(e.target.value)}
              rows={4}
              className="w-full rounded-md border border-input bg-background px-3 py-2 text-sm"
              placeholder="Add internal notes (not visible on GitHub)..."
            />
          </div>

          <button
            onClick={handleUpdate}
            disabled={isSaving}
            className="w-full rounded-md bg-primary px-4 py-2 text-sm text-primary-foreground hover:bg-primary/90 disabled:opacity-50"
          >
            {isSaving ? "Saving..." : "Save Changes"}
          </button>
        </div>

        <div className="space-y-4">
          <div>
            <h2 className="mb-2 text-lg font-semibold">Page URL</h2>
            <a
              href={bug_report.page_url}
              target="_blank"
              rel="noopener noreferrer"
              className="text-sm text-primary hover:underline"
            >
              {bug_report.page_url}
            </a>
          </div>

          {bug_report.user && (
            <div>
              <h2 className="mb-2 text-lg font-semibold">User</h2>
              <div className="rounded-md border border-input bg-background p-4">
                <p className="text-sm">
                  <strong>Name:</strong> {bug_report.user.name}
                </p>
                <p className="text-sm">
                  <strong>Email:</strong> {bug_report.user.email}
                </p>
                <a
                  href={`/admin/users/${bug_report.user.id}`}
                  className="text-sm text-primary hover:underline"
                >
                  View User →
                </a>
              </div>
            </div>
          )}

          {bug_report.screenshot_original_url && (
            <div>
              <h2 className="mb-2 text-lg font-semibold">Screenshots</h2>
              <div className="space-y-2">
                <div>
                  <p className="mb-1 text-sm font-medium">Original (Internal Only)</p>
                  <img
                    src={bug_report.screenshot_original_url}
                    alt="Original screenshot"
                    className="max-w-full rounded-md border border-input"
                  />
                </div>
                {bug_report.screenshot_sanitized_url && (
                  <div>
                    <p className="mb-1 text-sm font-medium">Sanitized (Public)</p>
                    <img
                      src={bug_report.screenshot_sanitized_url}
                      alt="Sanitized screenshot"
                      className="max-w-full rounded-md border border-input"
                    />
                  </div>
                )}
              </div>
            </div>
          )}

          {bug_report.console_logs_url && (
            <div>
              <h2 className="mb-2 text-lg font-semibold">Console Logs</h2>
              <a
                href={bug_report.console_logs_url}
                target="_blank"
                rel="noopener noreferrer"
                className="text-sm text-primary hover:underline"
              >
                Download Console Logs
              </a>
            </div>
          )}

          {bug_report.technical_context && Object.keys(bug_report.technical_context).length > 0 && (
            <div>
              <h2 className="mb-2 text-lg font-semibold">Technical Context</h2>
              <pre className="max-h-64 overflow-auto rounded-md border border-input bg-background p-4 text-xs">
                {JSON.stringify(bug_report.technical_context, null, 2)}
              </pre>
            </div>
          )}

          {bug_report.validation_result && (
            <div>
              <h2 className="mb-2 text-lg font-semibold">Validation Result</h2>
              <pre className="max-h-64 overflow-auto rounded-md border border-input bg-background p-4 text-xs">
                {JSON.stringify(bug_report.validation_result, null, 2)}
              </pre>
            </div>
          )}
        </div>
      </div>
    </section>
  );
}

