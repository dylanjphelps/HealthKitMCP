# Warmup/Cooldown Schema Improvements

**Date:** 2026-05-03

## Problem

The LLM was adding a default 5-minute warmup and cooldown to every scheduled workout because the `warmup` and `cooldown` schema fields had no guidance on when to include them. With no description, the model infers they are expected and fills them in.

## Goal

1. Stop the LLM from defaulting to adding warmup/cooldown unless explicitly requested.
2. Bring warmup/cooldown fields to full parity with block step fields.

## Changes

### File: `HealthKitMCP/MCP/Server.swift`

**1. Add descriptions to warmup and cooldown schema fields**

Both `warmup` and `cooldown` get a top-level `description` key:

- warmup: `"Optional. Omit unless the user explicitly requests a warmup. Do not add one by default."`
- cooldown: `"Optional. Omit unless the user explicitly requests a cooldown. Do not add one by default."`

**2. Add missing fields to warmup/cooldown property schemas**

| Field | Currently in warmup/cooldown | After |
|---|---|---|
| `goal_type` enum values | `time`, `distance` | `time`, `distance`, `open` |
| `target_pace_seconds_per_mile` | absent | added |

No changes to `goal_value`, `target_heart_rate_bpm`, or `display_name` — those are already present.

## Out of Scope

- No changes to `WorkoutKitManager.swift` — `makeStep` already handles all goal types and alert types.
- No changes to `ScheduleWorkoutTool.swift` — `parseStepSpec` already handles all fields.

## Testing

Verify by calling `schedule_workout` with a prompt that does not mention warmup or cooldown, and confirming the LLM omits those fields.
