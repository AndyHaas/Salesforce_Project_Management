/**
 * @description Small helpers for Lightning / Experience Cloud URL paths.
 * (Previously imported from portal add-on `portalCommon`; kept in core for task UI.)
 */

/**
 * Ensures Experience Cloud URLs include the /s prefix when needed.
 * @param {string} path target path (with or without leading slash)
 * @param {{ currentPathname?: string }} options optional current pathname for context
 * @returns {string} normalized path with required prefix
 */
export function ensureSitePath(path, { currentPathname = "" } = {}) {
  if (!path) {
    return "/";
  }

  const normalized = path.startsWith("/") ? path : `/${path}`;
  const isExperienceCloud = currentPathname.startsWith("/s/");

  if (isExperienceCloud && !normalized.startsWith("/s/")) {
    return `/s${normalized}`;
  }

  return normalized;
}