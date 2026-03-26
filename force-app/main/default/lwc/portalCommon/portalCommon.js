/**
 * Shared portal utilities and constants for header, footer, and content.
 */

// Keep patch in sync with commit count (bump each commit).
export const API_VERSION = {
    major: 0,
    minor: 1,
    patch: 194
};

export const BRAND_INFO = {
    name: 'Milestone Consulting',
    tagline:
        'Your secure portal for managing projects, tracking tasks, and staying connected with your Milestone Consulting team.',
    logoResource: 'https://milestoneconsulting.tech/assets/images/logos/MC_WHITE_UPDATED.png'
};

export const CONTACT_INFO = {
    email: 'info@milestoneconsulting.com',
    phone: '(817) 405-6960'
};

export const NAV_LINKS = [
    { label: 'Home', href: '/home' },
    { label: 'Projects', href: '/project/Project__c/Open_Projects' },
    { label: 'Project Tasks', href: '/project-task/Project_Task__c/All' }
];

export const RESOURCE_LINKS = [
    { label: 'FAQ & Policies', href: 'https://milestoneconsulting.tech/faq' }
];

export const DEFAULT_GREETING = 'Welcome';

export function getVersionLabel(prefix = 'Portal v') {
    return `${prefix}${API_VERSION.major}.${API_VERSION.minor}.${API_VERSION.patch}`;
}

/**
 * Build a welcome label using the user's first name when available.
 * @param {string} firstName user first name
 * @param {string} fallback fallback label when first name missing
 * @returns {string}
 */
export function getWelcomeLabel(firstName, fallback = DEFAULT_GREETING) {
    if (!firstName || !firstName.trim()) {
        return fallback;
    }
    return `${DEFAULT_GREETING} ${firstName.trim()}`;
}

/**
 * Ensures Experience Cloud URLs include the /s prefix when needed.
 * @param {string} path target path (with or without leading slash)
 * @param {{ currentPathname?: string }} options optional current pathname for context
 * @returns {string} normalized path with required prefix
 */
export function ensureSitePath(path, { currentPathname = '' } = {}) {
    if (!path) {
        return '/';
    }

    const normalized = path.startsWith('/') ? path : `/${path}`;
    const isExperienceCloud = currentPathname.startsWith('/s/');

    if (isExperienceCloud && !normalized.startsWith('/s/')) {
        return `/s${normalized}`;
    }

    return normalized;
}

/**
 * Get normalized field type string from Salesforce DisplayType or type string.
 * This maps Salesforce field types to normalized type strings used across portal components.
 * @param {string} displayType - Salesforce DisplayType string (e.g., 'PERCENT', 'CURRENCY') or normalized type
 * @param {object} options - Optional field metadata
 * @param {boolean} options.isHtmlFormatted - Whether the field is HTML formatted (for TextArea)
 * @param {number} options.length - Field length (for TextArea)
 * @returns {string} Normalized field type ('percent', 'currency', 'number', 'date', 'datetime', 'time', 'boolean', 'email', 'phone', 'url', 'richtext', 'textarea', 'text')
 */
export function getFieldType(displayType, options = {}) {
    if (!displayType) {
        return 'text';
    }

    const typeUpper = String(displayType).toUpperCase();

    // Map Salesforce DisplayType to normalized type strings
    if (typeUpper === 'PERCENT') {
        return 'percent';
    } else if (typeUpper === 'CURRENCY') {
        return 'currency';
    } else if (typeUpper === 'DOUBLE' || typeUpper === 'INTEGER' || typeUpper === 'LONG') {
        return 'number';
    } else if (typeUpper === 'DATE') {
        return 'date';
    } else if (typeUpper === 'DATETIME') {
        return 'datetime';
    } else if (typeUpper === 'TIME') {
        return 'time';
    } else if (typeUpper === 'BOOLEAN') {
        return 'boolean';
    } else if (typeUpper === 'EMAIL') {
        return 'email';
    } else if (typeUpper === 'PHONE') {
        return 'phone';
    } else if (typeUpper === 'URL') {
        return 'url';
    } else if (typeUpper === 'TEXTAREA') {
        // Differentiate between TextArea variants
        if (options.isHtmlFormatted === true) {
            return 'richtext';
        } else if (options.length && options.length > 255) {
            return 'textarea';
        } else {
            return 'textarea';
        }
    } else {
        // If already a normalized type, return as-is; otherwise default to 'text'
        const normalizedTypes = ['percent', 'currency', 'number', 'date', 'datetime', 'time', 'boolean', 'email', 'phone', 'url', 'richtext', 'textarea', 'text'];
        if (normalizedTypes.includes(displayType.toLowerCase())) {
            return displayType.toLowerCase();
        }
        return 'text';
    }
}

/**
 * Format a date value as YYYY-MM-DD
 * @param {string|Date} value - Date value to format
 * @param {string} emptyValue - Value to return if empty (default: '')
 * @returns {string} Formatted date string
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

/**
 * Format a datetime value as YYYY-MM-DD HH:MM
 * @param {string|Date} value - DateTime value to format
 * @param {string} emptyValue - Value to return if empty (default: '')
 * @returns {string} Formatted datetime string
 */
export function formatDateTime(value, emptyValue = '') {
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
    const hh = pad(date.getHours());
    const min = pad(date.getMinutes());
    return `${yyyy}-${mm}-${dd} ${hh}:${min}`;
}

/**
 * Format a time value
 * @param {number|string} value - Time value (milliseconds since midnight for Salesforce Time)
 * @param {string} emptyValue - Value to return if empty (default: '')
 * @returns {string} Formatted time string
 */
export function formatTime(value, emptyValue = '') {
    if (!value) {
        return emptyValue;
    }
    // Salesforce Time is typically in milliseconds since midnight
    if (typeof value === 'number') {
        const hours = Math.floor(value / (1000 * 60 * 60));
        const minutes = Math.floor((value % (1000 * 60 * 60)) / (1000 * 60));
        const seconds = Math.floor((value % (1000 * 60)) / 1000);
        const pad = (n) => String(n).padStart(2, '0');
        return `${pad(hours)}:${pad(minutes)}:${pad(seconds)}`;
    }
    return String(value);
}

/**
 * Format a phone number
 * @param {string} value - Phone number to format
 * @param {string} emptyValue - Value to return if empty (default: '')
 * @returns {string} Formatted phone number
 */
export function formatPhone(value, emptyValue = '') {
    if (!value) {
        return emptyValue;
    }
    // Remove all non-digit characters
    const digits = String(value).replace(/\D/g, '');
    if (digits.length === 10) {
        // Format as (XXX) XXX-XXXX
        return `(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}`;
    } else if (digits.length === 11 && digits.startsWith('1')) {
        // Format as +1 (XXX) XXX-XXXX
        return `+1 (${digits.substring(1, 4)}) ${digits.substring(4, 7)}-${digits.substring(7)}`;
    }
    // Return original if doesn't match standard formats
    return String(value);
}

/**
 * Format a boolean value as Yes/No
 * @param {boolean|string} value - Boolean value to format
 * @param {string} emptyValue - Value to return if empty (default: '')
 * @returns {string} 'Yes' or 'No'
 */
export function formatBoolean(value, emptyValue = '') {
    if (value === undefined || value === null || value === '') {
        return emptyValue;
    }
    return value === true || value === 'true' ? 'Yes' : 'No';
}

/**
 * Format a percent value
 * @param {number|string} value - Percent value (Salesforce stores 50 for 50%)
 * @param {string} emptyValue - Value to return if empty (default: '')
 * @returns {string} Formatted percent string with % symbol
 */
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

/**
 * Format a currency value
 * @param {number|string} value - Currency value
 * @param {string} currency - Currency code (default: 'USD')
 * @param {string} emptyValue - Value to return if empty (default: '')
 * @returns {string} Formatted currency string
 */
export function formatCurrency(value, currency = 'USD', emptyValue = '') {
    if (value === undefined || value === null || value === '') {
        return emptyValue;
    }
    const currencyValue = parseFloat(value);
    if (isNaN(currencyValue)) {
        return emptyValue;
    }
    return new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency: currency,
        minimumFractionDigits: 2,
        maximumFractionDigits: 2
    }).format(currencyValue);
}

/**
 * Format a number value
 * @param {number|string} value - Number value to format
 * @param {string} emptyValue - Value to return if empty (default: '')
 * @returns {string} Formatted number string
 */
export function formatNumber(value, emptyValue = '') {
    if (value === undefined || value === null || value === '') {
        return emptyValue;
    }
    const numValue = parseFloat(value);
    if (isNaN(numValue)) {
        return emptyValue;
    }
    // Format with appropriate decimal places
    return numValue % 1 === 0 ? numValue.toString() : numValue.toFixed(2);
}

/**
 * Strip HTML tags from a string
 * @param {string} html - HTML string to strip
 * @returns {string} Plain text without HTML tags
 */
export function stripHtml(html) {
    if (!html || typeof html !== 'string') {
        return html;
    }
    // Remove HTML tags and decode HTML entities
    const tmp = document.createElement('DIV');
    tmp.innerHTML = html;
    return tmp.textContent || tmp.innerText || '';
}

/**
 * Format a field value based on its type
 * @param {*} value - Field value to format
 * @param {string} fieldType - Normalized field type ('date', 'datetime', 'time', 'percent', 'currency', 'number', 'boolean', 'phone', 'richtext', 'textarea')
 * @param {object} options - Formatting options
 * @param {string} options.emptyValue - Value to return if empty (default: '')
 * @param {number} options.textareaMaxLength - Max length for textarea truncation (default: 100)
 * @returns {string} Formatted field value
 */
export function formatFieldValue(value, fieldType, options = {}) {
    const { emptyValue = '', textareaMaxLength = 100 } = options;
    
    if (value === undefined || value === null || value === '') {
        return emptyValue;
    }

    switch (fieldType) {
        case 'date':
            return formatDate(value, emptyValue);
        case 'datetime':
            return formatDateTime(value, emptyValue);
        case 'time':
            return formatTime(value, emptyValue);
        case 'percent':
            return formatPercent(value, emptyValue);
        case 'currency':
            return formatCurrency(value, 'USD', emptyValue);
        case 'number':
            return formatNumber(value, emptyValue);
        case 'boolean':
            return formatBoolean(value, emptyValue);
        case 'phone':
            return formatPhone(value, emptyValue);
        case 'richtext':
            return stripHtml(value);
        case 'textarea':
            if (typeof value === 'string' && value.length > textareaMaxLength) {
                return value.substring(0, textareaMaxLength) + '...';
            }
            return String(value);
        case 'email':
        case 'url':
        case 'text':
        default:
            return String(value);
    }
}
