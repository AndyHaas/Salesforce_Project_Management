/**
 * Shared helpers for AccountFilter LMS payloads and effective account Id lists
 * used by dashboard metrics and task list LWCs.
 */

/**
 * Derives account Id array from an AccountFilter__c message body.
 *
 * @param {object} [message] LMS payload
 * @returns {string[]|undefined} New filter list when message defines accountIds/accountId; undefined if no applicable keys
 */
export function accountIdsFromFilterMessage(message) {
  if (!message) {
    return undefined;
  }
  if (message.accountIds !== undefined) {
    return Array.isArray(message.accountIds) ? message.accountIds : [];
  }
  if (message.accountId !== undefined) {
    return message.accountId ? [message.accountId] : [];
  }
  return undefined;
}

/**
 * Effective account Ids for dashboard wires: LMS multi-select wins, else single @api accountId.
 *
 * @param {string[]} filteredAccountIds from LMS (may be empty)
 * @param {string} [accountId] @api accountId
 * @returns {string[]}
 */
export function resolveEffectiveAccountIds(filteredAccountIds, accountId) {
  const filtered = filteredAccountIds || [];
  if (filtered.length > 0) {
    return filtered;
  }
  return accountId ? [accountId] : [];
}
