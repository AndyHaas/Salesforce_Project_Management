/** Standard Account record Id prefix (same in all orgs). */
export const STANDARD_ACCOUNT_KEY_PREFIX = "001";

export const ACCOUNT_SEL_THIS = "__THIS_ACCOUNT__";
export const ACCOUNT_SEL_ALL = "__ALL_ACCOUNTS__";

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
    return (
      sa.substring(0, 15).toLowerCase() === sb.substring(0, 15).toLowerCase()
    );
  }
  return false;
}
