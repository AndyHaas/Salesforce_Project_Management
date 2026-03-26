@isTest
public class slack_tst_Project {
	@isTest 
	static void testTrigger() {
		Project__c obj0 = new Project__c(
			Status__c = 'Not Started'
		);
		insert obj0;
	}
}