import type { Approval } from "$lib/api/types";
import { approvals as approvalsApi } from "$lib/api/client";

class ApprovalsStore {
  approvals = $state<Approval[]>([]);
  loading = $state(false);
  error = $state<string | null>(null);

  pendingCount = $derived(
    this.approvals.filter((a) => a.status === "pending").length,
  );

  pendingApprovals = $derived(
    this.approvals.filter((a) => a.status === "pending"),
  );

  async fetchApprovals(): Promise<void> {
    this.loading = true;
    this.error = null;
    try {
      const data = await approvalsApi.list();
      this.approvals = data.approvals ?? [];
    } catch (err) {
      this.error =
        err instanceof Error ? err.message : "Failed to fetch approvals";
    } finally {
      this.loading = false;
    }
  }

  async resolve(
    id: number,
    decision: "approve" | "reject" | "request-revision",
    notes: string,
  ): Promise<void> {
    await approvalsApi.resolve(id, decision, notes, "operator");
    await this.fetchApprovals();
  }

  async approve(id: number, notes: string): Promise<void> {
    return this.resolve(id, "approve", notes);
  }

  async reject(id: number, notes: string): Promise<void> {
    return this.resolve(id, "reject", notes);
  }

  async requestRevision(id: number, notes: string): Promise<void> {
    return this.resolve(id, "request-revision", notes);
  }
}

export const approvalsStore = new ApprovalsStore();
