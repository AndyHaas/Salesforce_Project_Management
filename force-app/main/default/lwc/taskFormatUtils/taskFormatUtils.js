/**
 * Shared date/number formatting for internal LWCs (aligned with portal display rules).
 * Kept in core so components like taskDetail do not depend on the Portal add-on package.
 */

export function formatDate(value, emptyValue = '') {
    if (!value) {
        return emptyValue;
    }
    const date = new Date(value);
    if (isNaN(date.getTime())) {
        return value;
    }
    const pad = (n) => String(n).padStart(2, '0');
    const yyyy = date.getFullYear();
    const mm = pad(date.getMonth() + 1);
    const dd = pad(date.getDate());
    return `${yyyy}-${mm}-${dd}`;
}

export function formatPercent(value, emptyValue = '') {
    if (value === undefined || value === null || value === '') {
        return emptyValue;
    }
    const percentValue = parseFloat(value);
    if (isNaN(percentValue)) {
        return emptyValue;
    }
    return `${percentValue.toFixed(2)}%`;
}

export function formatNumber(value, emptyValue = '') {
    if (value === undefined || value === null || value === '') {
        return emptyValue;
    }
    const numValue = parseFloat(value);
    if (isNaN(numValue)) {
        return emptyValue;
    }
    return numValue % 1 === 0 ? numValue.toString() : numValue.toFixed(2);
}
