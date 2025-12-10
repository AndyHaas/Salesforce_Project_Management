import { LightningElement, api } from 'lwc';
import {
    BRAND_INFO,
    CONTACT_INFO,
    NAV_LINKS,
    RESOURCE_LINKS,
    getVersionLabel
} from 'c/portalCommon';

export default class PortalFooter extends LightningElement {
    @api versionLabel = getVersionLabel();

    navLinks = NAV_LINKS;
    resourceLinks = RESOURCE_LINKS;
    brand = BRAND_INFO;
    contact = {
        ...CONTACT_INFO,
        emailHref: `mailto:${CONTACT_INFO.email}`,
        phoneHref: `tel:${CONTACT_INFO.phone.replace(/[^+\d]/g, '')}`
    };

    get currentYear() {
        return new Date().getFullYear();
    }
}
