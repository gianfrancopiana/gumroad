import { router, usePage } from "@inertiajs/react";
import React, { useState } from "react";

type BugReport = {
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
  user: {
    id: string;
    email: string;
    name: string;
  } | null;
};

type PageProps = {
  bug_reports: BugReport[];
  pagination: {
    page: number;
    pages: number;
  };
  filters: {
    status?: string;
    category?: string;
    user_type?: string;
  };
};

export default function AdminBugReportsIndex() {
  const props = usePage<PageProps>().props;
  const [statusFilter, setStatusFilter] = useState(props.filters?.status || "");

  const handleStatusFilter = (status: string) => {
    setStatusFilter(status);
    router.get("/admin/bug_reports", { status: status || undefined }, { preserveState: true });
  };

  return (
    <section>
      <div className="mb-4 flex items-center justify-end">
        <select
          value={statusFilter}
          onChange={(e) => handleStatusFilter(e.target.value)}
          className="w-auto rounded-md border border-input bg-background px-3 py-2 text-sm"
        >
          <option value="">All statuses</option>
          <option value="pending">Pending</option>
          <option value="validated">Validated</option>
          <option value="rejected">Rejected</option>
          <option value="needs_clarification">Needs clarification</option>
          <option value="github_created">GitHub created</option>
          <option value="resolved">Resolved</option>
          <option value="duplicate">Duplicate</option>
        </select>
      </div>

      <div className="overflow-x-auto">
        <table className="w-full border-collapse">
          <thead>
            <tr className="border-b">
              <th className="px-4 py-2 text-left text-sm font-medium">ID</th>
              <th className="px-4 py-2 text-left text-sm font-medium">Title</th>
              <th className="px-4 py-2 text-left text-sm font-medium">Status</th>
              <th className="px-4 py-2 text-left text-sm font-medium">Category</th>
              <th className="px-4 py-2 text-left text-sm font-medium">User Type</th>
              <th className="px-4 py-2 text-left text-sm font-medium">Quality Score</th>
              <th className="px-4 py-2 text-left text-sm font-medium">GitHub</th>
              <th className="px-4 py-2 text-left text-sm font-medium">Created</th>
            </tr>
          </thead>
          <tbody>
            {props.bug_reports.length === 0 ? (
              <tr>
                <td colSpan={8} className="px-4 py-8 text-center text-sm text-muted-foreground">
                  No bug reports found
                </td>
              </tr>
            ) : (
              props.bug_reports.map((report) => (
                <tr key={report.id} className="border-b hover:bg-accent/50">
                  <td className="px-4 py-2 text-sm">
                    <a
                      href={`/admin/bug_reports/${report.id}`}
                      className="text-primary hover:underline"
                    >
                      {report.id.slice(0, 8)}...
                    </a>
                  </td>
                  <td className="px-4 py-2 text-sm">{report.title || "Untitled"}</td>
                  <td className="px-4 py-2 text-sm">
                    <span className="rounded-full bg-muted px-2 py-1 text-xs">
                      {report.status}
                    </span>
                  </td>
                  <td className="px-4 py-2 text-sm">{report.category || "-"}</td>
                  <td className="px-4 py-2 text-sm">{report.user_type}</td>
                  <td className="px-4 py-2 text-sm">
                    {report.quality_score ? `${report.quality_score}/100` : "-"}
                  </td>
                  <td className="px-4 py-2 text-sm">
                    {report.github_issue_url ? (
                      <a
                        href={report.github_issue_url}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="text-primary hover:underline"
                      >
                        #{report.github_issue_number}
                      </a>
                    ) : (
                      "-"
                    )}
                  </td>
                  <td className="px-4 py-2 text-sm">
                    {new Date(report.created_at).toLocaleDateString()}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {props.pagination && props.pagination.pages > 1 && (
        <div className="mt-4 flex items-center justify-between">
          <p className="text-sm text-muted-foreground">
            Page {props.pagination.page} of {props.pagination.pages}
          </p>
          <div className="flex gap-2">
            {props.pagination.page > 1 && (
              <button
                onClick={() => router.get("/admin/bug_reports", { page: props.pagination.page - 1 })}
                className="rounded-md border border-input bg-background px-4 py-2 text-sm hover:bg-accent"
              >
                Previous
              </button>
            )}
            {props.pagination.page < props.pagination.pages && (
              <button
                onClick={() => router.get("/admin/bug_reports", { page: props.pagination.page + 1 })}
                className="rounded-md border border-input bg-background px-4 py-2 text-sm hover:bg-accent"
              >
                Next
              </button>
            )}
          </div>
        </div>
      )}
    </section>
  );
}

