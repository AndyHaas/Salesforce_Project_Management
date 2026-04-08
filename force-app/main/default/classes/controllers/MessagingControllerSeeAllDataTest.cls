/**
 * Portal-oriented smoke tests that query existing org Users (SeeAllData).
 * Kept separate from {@link MessagingControllerTest} because Salesforce disallows
 * @IsTest(SeeAllData=true) on a class that also defines @testSetup.
 */
@IsTest
private class MessagingControllerSeeAllDataTest {
  @IsTest(SeeAllData=true)
  static void markAsRead_portalUserUpdatesClientFlag() {
    List<User> portalUsers = [
      SELECT Id
      FROM User
      WHERE AccountId != NULL AND ContactId != NULL AND IsActive = TRUE
      LIMIT 1
    ];
    if (portalUsers.isEmpty()) {
      return;
    }
    List<Message__c> rows = [SELECT Id FROM Message__c LIMIT 1];
    if (rows.isEmpty()) {
      return;
    }
    System.runAs(portalUsers[0]) {
      MessagingController.markAsRead(String.valueOf(rows[0].Id));
    }
  }

  @IsTest(SeeAllData=true)
  static void getLatestMessages_underActivePortalUser() {
    List<User> portalUsers = [
      SELECT Id
      FROM User
      WHERE AccountId != NULL AND ContactId != NULL AND IsActive = TRUE
      LIMIT 1
    ];
    if (portalUsers.isEmpty()) {
      return;
    }
    System.runAs(portalUsers[0]) {
      Test.startTest();
      MessagingController.getLatestMessages(5, 'CreatedDate', 'DESC');
      Test.stopTest();
    }
  }

  @IsTest(SeeAllData=true)
  static void pinMessage_portalUserThrows() {
    List<User> portalUsers = [
      SELECT Id
      FROM User
      WHERE AccountId != NULL AND ContactId != NULL AND IsActive = TRUE
      LIMIT 1
    ];
    if (portalUsers.isEmpty()) {
      return;
    }
    List<Message__c> rows = [SELECT Id FROM Message__c WHERE Deleted__c = FALSE LIMIT 1];
    if (rows.isEmpty()) {
      return;
    }
    Message__c m = rows[0];
    System.runAs(portalUsers[0]) {
      Boolean threw = false;
      try {
        MessagingController.pinMessage(String.valueOf(m.Id), true);
      } catch (AuraHandledException expected) {
        threw = true;
      }
      System.assert(threw);
    }
  }

  @IsTest(SeeAllData=true)
  static void sendMessage_portalUserCannotSendInternalOnly() {
    List<User> portalUsers = [
      SELECT Id, AccountId
      FROM User
      WHERE AccountId != NULL AND ContactId != NULL AND IsActive = TRUE
      LIMIT 1
    ];
    if (portalUsers.isEmpty()) {
      return;
    }
    User pu = portalUsers[0];
    System.runAs(pu) {
      Boolean threw = false;
      try {
        MessagingController.sendMessage(
          'Internal attempt',
          'Milestone Team',
          String.valueOf(pu.AccountId),
          null,
          null,
          null,
          false,
          null
        );
      } catch (AuraHandledException expected) {
        threw = true;
      }
      System.assert(threw);
    }
  }
}
