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
    name: string | null;
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
          internal_notes: internalNotes,
        },
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
        <p className="text-muted-foreground text-sm">ID: {bug_report.id}</p>
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <div className="space-y-4">
          <div>
            <h2 className="mb-2 text-lg font-semibold">Description</h2>
            <div className="border-input rounded-md border bg-background p-4">
              <p className="whitespace-pre-wrap">{bug_report.description}</p>
            </div>
          </div>

          {bug_report.sanitized_description && bug_report.sanitized_description !== bug_report.description && (
            <div>
              <h2 className="mb-2 text-lg font-semibold">Sanitized description</h2>
              <div className="border-input rounded-md border bg-background p-4">
                <p className="whitespace-pre-wrap">{bug_report.sanitized_description}</p>
              </div>
            </div>
          )}

          <div>
            <h2 className="mb-2 text-lg font-semibold">Metadata</h2>
            <div className="border-input space-y-3 rounded-md border bg-background p-4">
              <div className="flex items-center gap-4 py-1">
                <span className="text-muted-foreground w-32 shrink-0 text-sm font-medium">Status</span>
                <select
                  value={status}
                  onChange={(e) => setStatus(e.target.value)}
                  className="border-input focus:ring-primary min-w-0 flex-1 rounded-md border bg-background px-3 py-1.5 text-sm font-medium focus:ring-2 focus:ring-offset-0 focus:outline-none"
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
              <div className="flex items-center gap-4 py-1">
                <span className="text-muted-foreground w-32 shrink-0 text-sm font-medium">Category</span>
                <span className="rounded-full bg-muted px-2.5 py-0.5 text-xs font-medium capitalize">
                  {bug_report.category || "-"}
                </span>
              </div>
              <div className="flex items-center gap-4 py-1">
                <span className="text-muted-foreground w-32 shrink-0 text-sm font-medium">Severity</span>
                <span className="rounded-full bg-muted px-2.5 py-0.5 text-xs font-medium capitalize">
                  {bug_report.severity || "-"}
                </span>
              </div>
              <div className="flex items-center gap-4 py-1">
                <span className="text-muted-foreground w-32 shrink-0 text-sm font-medium">Quality score</span>
                <span className="text-sm font-medium">
                  {bug_report.quality_score ? `${bug_report.quality_score}/100` : "-"}
                </span>
              </div>
              <div className="flex items-center gap-4 py-1">
                <span className="text-muted-foreground w-32 shrink-0 text-sm font-medium">User type</span>
                <span className="rounded-full bg-muted px-2.5 py-0.5 text-xs font-medium capitalize">
                  {bug_report.user_type}
                </span>
              </div>
              {bug_report.github_issue_url && (
                <div className="flex items-center gap-4 py-1">
                  <span className="text-muted-foreground w-32 shrink-0 text-sm font-medium">GitHub issue</span>
                  <a
                    href={bug_report.github_issue_url}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-primary text-sm font-medium hover:underline"
                  >
                    #{bug_report.github_issue_number}
                  </a>
                </div>
              )}
            </div>
          </div>

          <div>
            <h2 className="mb-2 text-lg font-semibold">Internal notes</h2>
            <textarea
              value={internalNotes}
              onChange={(e) => setInternalNotes(e.target.value)}
              rows={4}
              className="border-input w-full rounded-md border bg-background px-3 py-2 text-sm"
              placeholder="Add internal notes (not visible on GitHub)..."
            />
          </div>

          <button
            onClick={handleUpdate}
            disabled={isSaving}
            className="bg-primary text-primary-foreground hover:bg-primary/90 w-full rounded-md px-4 py-2 text-sm disabled:opacity-50"
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
              className="text-primary text-sm hover:underline"
            >
              {bug_report.page_url}
            </a>
          </div>

          {bug_report.user && (
            <div>
              <h2 className="mb-2 text-lg font-semibold">User</h2>
              <div className="border-input rounded-md border bg-background p-4">
                <p className="text-sm">
                  <strong>Name:</strong> {bug_report.user.name || "N/A"}
                </p>
                <p className="text-sm">
                  <strong>Email:</strong> {bug_report.user.email}
                </p>
                <a href={`/admin/users/${bug_report.user.id}`} className="text-primary text-sm hover:underline">
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
                  <p className="mb-1 text-sm font-medium">Original (Internal only)</p>
                  <img
                    src={bug_report.screenshot_original_url}
                    alt="Original screenshot"
                    className="border-input max-w-full rounded-md border"
                  />
                </div>
                {bug_report.screenshot_sanitized_url && (
                  <div>
                    <p className="mb-1 text-sm font-medium">Sanitized (public)</p>
                    <img
                      src={bug_report.screenshot_sanitized_url}
                      alt="Sanitized screenshot"
                      className="border-input max-w-full rounded-md border"
                    />
                  </div>
                )}
              </div>
            </div>
          )}

          {bug_report.console_logs_url && (
            <div>
              <h2 className="mb-2 text-lg font-semibold">Console logs</h2>
              <a
                href={bug_report.console_logs_url}
                target="_blank"
                rel="noopener noreferrer"
                className="text-primary text-sm hover:underline"
              >
                Download Console Logs
              </a>
            </div>
          )}

          {bug_report.technical_context && Object.keys(bug_report.technical_context).length > 0 && (
            <div>
              <h2 className="mb-2 text-lg font-semibold">Technical context</h2>
              <pre className="border-input max-h-64 overflow-auto rounded-md border bg-background p-4 text-xs">
                {JSON.stringify(bug_report.technical_context, null, 2)}
              </pre>
            </div>
          )}

          {bug_report.validation_result && (
            <div>
              <h2 className="mb-2 text-lg font-semibold">Validation result</h2>
              <pre className="border-input max-h-64 overflow-auto rounded-md border bg-background p-4 text-xs">
                {JSON.stringify(bug_report.validation_result, null, 2)}
              </pre>
            </div>
          )}
        </div>
      </div>
    </section>
  );
}
