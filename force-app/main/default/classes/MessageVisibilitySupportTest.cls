/**
 * Tests {@link MessageVisibilitySupport#visibleToClientForNewMessage}.
 */
@IsTest
private class MessageVisibilitySupportTest {
  @IsTest
  static void portalSender_alwaysVisibleToClient() {
    System.assertEquals(
      true,
      MessageVisibilitySupport.visibleToClientForNewMessage(
        false,
        'Milestone Team'
      )
    );
    System.assertEquals(
      true,
      MessageVisibilitySupport.visibleToClientForNewMessage(false, 'Client')
    );
    System.assertEquals(
      true,
      MessageVisibilitySupport.visibleToClientForNewMessage(
        null,
        'Milestone Team'
      )
    );
  }

  @IsTest
  static void internalSender_followsRecipientType() {
    System.assertEquals(
      true,
      MessageVisibilitySupport.visibleToClientForNewMessage(true, 'Client')
    );
    System.assertEquals(
      false,
      MessageVisibilitySupport.visibleToClientForNewMessage(
        true,
        'Milestone Team'
      )
    );
  }
}
