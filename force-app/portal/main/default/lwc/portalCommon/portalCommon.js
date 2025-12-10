/**
 * Shared portal utilities and constants for header, footer, and content.
 */

export const API_VERSION = {
    major: 0,
    minor: 1,
    patch: 33
};

export const BRAND_INFO = {
    name: 'Milestone Consulting',
    tagline:
        'Your secure portal for managing projects, tracking tasks, and staying connected with your Milestone Consulting team.',
    logoResource: '/sfsites/c/resource/MilestoneLogo_White'
};

export const CONTACT_INFO = {
    email: 'info@milestoneconsulting.com',
    phone: '(817) 405-6960'
};

export const NAV_LINKS = [
    { label: 'Home', href: '/home' },
    { label: 'Account', href: '/account' },
    { label: 'Projects', href: '/projects' },
    { label: 'Tasks', href: '/tasks' }
];

export const RESOURCE_LINKS = [
    { label: 'FAQ & Help', href: '/faq' },
    { label: 'Portal Guide', href: '/help' },
    { label: 'Privacy Policy', href: '/policies' },
    { label: 'Terms of Use', href: '/terms' }
];

export function getVersionLabel(prefix = 'Portal v') {
    return `${prefix}${API_VERSION.major}.${API_VERSION.minor}.${API_VERSION.patch}`;
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
