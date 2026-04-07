/**
 * Creates or reuses {@link ContentDistribution} rows for in-browser file preview on Experience Cloud.
 * Runs without sharing so portal users are not blocked by missing ContentDistribution CRUD on their profile;
 * callers must verify the running user can read the {@link ContentVersion} before invoking (see
 * {@link MessageFilesSupport#getFilePreviewUrl}).
 */
public without sharing class MessageFilesPreviewWorker {
  /**
   * Returns a public distribution URL for iframe / new-tab preview of the given ContentVersion.
   *
   * @param contentVersionId Valid ContentVersion Id.
   * @return {@link ContentDistribution#DistributionPublicUrl} for view-in-browser distribution.
   */
  public static String getDistributionPublicUrlForContentVersion(Id contentVersionId) {
    if (contentVersionId == null) {
      throw new AuraHandledException('Content Version ID is required');
    }

    List<ContentDistribution> existingDistributions = [
      SELECT DistributionPublicUrl
      FROM ContentDistribution
      WHERE ContentVersionId = :contentVersionId AND PreferencesAllowViewInBrowser = TRUE
      LIMIT 1
    ];

    if (!existingDistributions.isEmpty()) {
      return existingDistributions[0].DistributionPublicUrl;
    }

    ContentDistribution dist = new ContentDistribution();
    dist.ContentVersionId = contentVersionId;
    dist.Name = 'Preview Distribution';
    dist.PreferencesAllowViewInBrowser = true;
    dist.PreferencesLinkLatestVersion = true;
    dist.PreferencesAllowOriginalDownload = true;

    insert dist;

    ContentDistribution createdDist = [
      SELECT DistributionPublicUrl
      FROM ContentDistribution
      WHERE Id = :dist.Id
      LIMIT 1
    ];

    return createdDist.DistributionPublicUrl;
  }
}
