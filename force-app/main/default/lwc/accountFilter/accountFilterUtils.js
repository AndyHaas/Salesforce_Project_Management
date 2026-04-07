/**
 * Pure helpers for account picklist filtering and LMS payload shape.
 * Used by accountFilter for testability.
 */

/**
 * @param {Array<{ label: string, value: string }>} accounts
 * @param {string[]} selectedAccountIds
 * @param {string} searchTerm
 * @returns {Array<{ label: string, value: string }>}
 */
export function filterAccountPicklistOptions(accounts, selectedAccountIds, searchTerm) {
  const selected = selectedAccountIds || [];
  const excludeSelected = (accounts || []).filter((acc) => !selected.includes(acc.value));
  if (!searchTerm || searchTerm.trim() === "") {
    return excludeSelected;
  }
  const searchLower = searchTerm.toLowerCase();
  return excludeSelected.filter((acc) => acc.label.toLowerCase().includes(searchLower));
}

/**
 * @param {string[]} selectedAccountIds
 * @returns {{ accountIds: string[], accountId: string|null|"" }}
 */
export function buildAccountFilterPayload(selectedAccountIds) {
  const ids = selectedAccountIds || [];
  return {
    accountIds: ids,
    accountId:
      ids.length === 1 ? ids[0] : ids.length === 0 ? "" : null
  };
}
