/**
 * Admin build flags. Vite exposes only VITE_ variables, the same mechanism
 * as VITE_API_BASE_URL. Staging and production Netlify sites do not set
 * VITE_RIDER_ONLINE_TIME_ENABLED, so the page stays hidden. Set that variable
 * to the string true only when the feature is released.
 */
const configured = import.meta.env?.VITE_RIDER_ONLINE_TIME_ENABLED;
export const RIDER_ONLINE_TIME_ENABLED = configured === 'true';
