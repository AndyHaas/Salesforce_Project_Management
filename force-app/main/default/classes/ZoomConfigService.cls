/**
 * @description Reads Zoom_Webhook_Config__mdt (Default record) for webhook and processing behavior.
 */
public with sharing class ZoomConfigService {
    private static final String DEFAULT_CONFIG = 'Default';

    /**
     * @description Custom metadata row used for integration settings.
     */
    public static Zoom_Webhook_Config__mdt getDefault() {
        return Zoom_Webhook_Config__mdt.getInstance(DEFAULT_CONFIG);
    }
}
