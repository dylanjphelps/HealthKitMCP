# Elevation Smoothing Fix — 2026-05-09

## Summary

Fixed GPS elevation computation on Apple Watch by implementing moving average smoothing of barometric altitude data with 0.05m threshold.

## Changes

**Franky (iOS Dev):**
- Added `smoothAltitudes()` moving average function (window: 5)
- Modified `computeRouteElevation()` to smooth before delta computation
- Adjusted threshold from 0.1m → 0.3m → 0.05m (final)

**Usopp (Tester):**
- Updated 2 existing elevation tests
- Added 5 new `smoothAltitudes()` tests
- Added 1 realistic GPS regression test

**Coordinator:**
- Verified 0.05m threshold mathematically
- Final result: 76 tests, 0 failures

## Outcome

✅ Complete. All tests passing. Apple Watch elevation data now properly smoothed.
