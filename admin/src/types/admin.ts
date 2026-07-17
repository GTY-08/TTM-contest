import type { Session, User } from '@supabase/supabase-js';

export type JsonMap = Record<string, unknown>;

export type AdminAuthState = {
  loading: boolean;
  session: Session | null;
  user: User | null;
  isAdmin: boolean;
  nickname: string;
};

export type RpcListResult<T extends JsonMap = JsonMap> = {
  ok?: boolean;
  items?: T[];
  total_count?: number;
};

export type DashboardMetrics = JsonMap & {
  total_users?: number;
  today_requests?: number;
  open_requests?: number;
  matched_requests?: number;
  completed_requests?: number;
  cancelled_requests?: number;
  failed_requests?: number;
  pending_user_reports?: number;
  pending_message_reports?: number;
};

export type PageState<T> = {
  loading: boolean;
  error: string | null;
  data: T | null;
};
