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
