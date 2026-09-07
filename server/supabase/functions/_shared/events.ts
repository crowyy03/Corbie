import { ApiError, isUuid } from "./respond.ts";

export const allowedEventNames = new Set([
  "app_open",
  "onboarding_step",
  "space_created",
  "invite_created",
  "invite_redeemed",
  "task_created",
  "task_taken",
  "task_done",
  "task_handed_back",
  "event_created",
  "wish_created",
  "wish_fulfilled",
  "plan_created",
  "plan_completed",
  "plan_step_created",
  "plan_step_done",
  "expense_added",
  "list_created",
  "list_item_checked",
  "list_map_opened",
  "freetime_opened",
  "freetime_sharing_enabled",
  "freetime_sharing_disabled",
  "freetime_slot_tapped",
  "freetime_empty",
  "capsule_created",
  "capsule_opened",
  "vote_created",
  "vote_answered",
  "vote_revealed",
  "widget_added",
  "paywall_shown",
  "trial_started",
  "purchase",
  "restore",
  "readonly_hit",
  "today_opened",
  "today_block_tapped",
  "today_quick_action",
  "recap_shown",
  "recap_notification_sent",
  "recap_opened",
  "question_shown",
  "question_answered",
  "question_revealed",
  "question_nudge_sent",
  "question_history_opened",
  "chore_flow_started",
  "chore_list_built",
  "chore_rating_done",
  "chore_revealed",
  "chore_applied",
  "chore_resplit",
]);

export const droppedPropKeys = new Set([
  "email",
  "name",
  "phone",
  "title",
  "body",
  "text",
  "url",
]);

export const maxEventsPerBatch = 50;
export const maxPropKeys = 10;
export const maxPropLength = 200;

export type PropValue = string | number | boolean | null;

export interface IncomingEvent {
  name?: unknown;
  props?: unknown;
  ts?: unknown;
  appVersion?: unknown;
  locale?: unknown;
}

export interface StoredEvent {
  anon_id: string;
  name: string;
  props: Record<string, PropValue>;
  ts: string;
  app_version: string | null;
  locale: string | null;
}

export function sanitizeProps(raw: unknown): Record<string, PropValue> {
  if (typeof raw !== "object" || raw === null || Array.isArray(raw)) return {};
  const result: Record<string, PropValue> = {};
  for (const [key, value] of Object.entries(raw as Record<string, unknown>)) {
    if (Object.keys(result).length >= maxPropKeys) break;
    const lower = key.toLowerCase();
    if (droppedPropKeys.has(lower)) continue;
    if (key.length === 0 || key.length > 40) continue;
    if (typeof value === "string") {
      result[key] = value.slice(0, maxPropLength);
    } else if (typeof value === "number" && Number.isFinite(value)) {
      result[key] = value;
    } else if (typeof value === "boolean" || value === null) {
      result[key] = value;
    }
  }
  return result;
}

function sanitizeShortText(value: unknown, limit: number): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  if (trimmed.length === 0) return null;
  return trimmed.slice(0, limit);
}

function sanitizeTimestamp(value: unknown, now: Date): string {
  if (typeof value !== "string") return now.toISOString();
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return now.toISOString();
  const future = new Date(now.getTime() + 60 * 60 * 1000);
  const past = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
  if (parsed > future || parsed < past) return now.toISOString();
  return parsed.toISOString();
}

export function requireAnonId(header: string | null): string {
  if (!isUuid(header)) throw new ApiError("invalid_request", "X-Anon-Id must be a UUID");
  return header.toLowerCase();
}

export function sanitizeBatch(anonId: string, raw: unknown, now: Date = new Date()): StoredEvent[] {
  if (typeof raw !== "object" || raw === null) {
    throw new ApiError("invalid_request", "events must be an array");
  }
  const list = (raw as { events?: unknown }).events;
  if (!Array.isArray(list)) throw new ApiError("invalid_request", "events must be an array");
  if (list.length > maxEventsPerBatch) {
    throw new ApiError("invalid_request", `events must hold at most ${maxEventsPerBatch} items`);
  }

  const result: StoredEvent[] = [];
  for (const entry of list) {
    if (typeof entry !== "object" || entry === null) continue;
    const event = entry as IncomingEvent;
    if (typeof event.name !== "string" || !allowedEventNames.has(event.name)) continue;
    result.push({
      anon_id: anonId,
      name: event.name,
      props: sanitizeProps(event.props),
      ts: sanitizeTimestamp(event.ts, now),
      app_version: sanitizeShortText(event.appVersion, 40),
      locale: sanitizeShortText(event.locale, 20),
    });
  }
  return result;
}
