/**
 * Planning speed shared with the mock router: 30 km/h.
 * Fare snapshots store distance_km and do not store a Google duration.
 * Offer ETA uses this so listing an offer does not call the routing provider again.
 */
export const PLANNED_SPEED_MPS = 30_000 / 3600;

export function plannedTripDurationSeconds(distanceKm: number): number {
  if (!Number.isFinite(distanceKm) || distanceKm <= 0) {
    return 0;
  }
  const meters = distanceKm * 1000;
  return Math.max(1, Math.round(meters / PLANNED_SPEED_MPS));
}
