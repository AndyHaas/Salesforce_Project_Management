/** Standard Account record Id prefix (same in all orgs). */
export const STANDARD_ACCOUNT_KEY_PREFIX = "001";

export const ACCOUNT_SEL_THIS = "__THIS_ACCOUNT__";
export const ACCOUNT_SEL_ALL = "__ALL_ACCOUNTS__";

/**
 * True when CurrentPageReference.type indicates an Experience Cloud (community) page.
 * Covers Aura-based (comm__) and LWR (comm_lwr__) builders.
 *
 * @param {string} [type] pageReference.type from CurrentPageReference
 * @returns {boolean}
 */
export function isExperienceCloudPageReferenceType(type) {
  if (type == null || type === undefined) {
    return false;
  }
  const t = String(type);
  return t.startsWith("comm__") || t.startsWith("comm_lwr__");
}

/**
 * Best-effort Experience Cloud detection from window.location (custom domains may not match).
 * Excludes Lightning Experience hosts (*.lightning.force.com).
 *
 * @param {object} [loc]
 * @param {string} [loc.hostname]
 * @param {string} [loc.pathname]
 * @returns {boolean}
 */
export function inferExperienceCloudFromBrowserLocation(loc = {}) {
  const hostname = (loc.hostname || "").toLowerCase().trim();
  const pathname = loc.pathname || "";

  if (pathname === "/s" || pathname.startsWith("/s/")) {
    return true;
  }

  if (!hostname) {
    return false;
  }

  // Lightning Experience — not a member site
  if (hostname.includes(".lightning.force.com") || hostname.endsWith(".lightning.force.com")) {
    return false;
  }

  // Experience Cloud standard host patterns
  if (hostname.includes(".my.site.com") || hostname.includes(".my.site-preview.com")) {
    return true;
  }

  // Builder / preview tooling
  if (/live-preview/i.test(hostname)) {
    return true;
  }

  // *.force.com tenant URLs that are not LEX subdomains (heuristic)
  if (hostname.endsWith(".force.com") && !hostname.includes(".lightning.")) {
    return true;
  }

  // Legacy / alternate Experience hostnames (narrow)
  if (hostname.includes(".site.com") && !hostname.includes("lightning.")) {
    return true;
  }

  return false;
}

/** Compare Salesforce Ids allowing 15- vs 18-char forms */
export function salesforceIdsEqual(a, b) {
  if (a == null || b == null) {
    return false;
  }
  const sa = String(a).trim();
  const sb = String(b).trim();
  if (sa === sb) {
    return true;
  }
  if (sa.length >= 15 && sb.length >= 15) {
    return sa.substring(0, 15).toLowerCase() === sb.substring(0, 15).toLowerCase();
  }
  return false;
}
