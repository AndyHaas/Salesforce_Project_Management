/**
 * Temporary test class to verify Platform Cache is enabled and working
 * This can be deleted after verification
 */
public class PlatformCacheTest {
    
    /**
     * Test method to verify Platform Cache is enabled
     * Run this in Anonymous Apex or Developer Console
     */
    public static void testPlatformCache() {
        try {
            String testKey = 'test_cache_' + String.valueOf(DateTime.now().getTime());
            String testValue = 'test_value_' + String.valueOf(Math.random());
            
            // Try to store in Platform Cache
            Cache.Org.put(testKey, testValue, 60); // 60 seconds
            
            // Try to retrieve from Platform Cache
            String retrievedValue = (String)Cache.Org.get(testKey);
            
            if (retrievedValue == testValue) {
                System.debug('✅ Platform Cache is ENABLED and WORKING');
                System.debug('Successfully stored and retrieved: ' + retrievedValue);
                
                // Clean up
                Cache.Org.remove(testKey);
            } else {
                System.debug('❌ Platform Cache test FAILED - values do not match');
            }
            
        } catch (Exception e) {
            System.debug('❌ Platform Cache is NOT ENABLED or ERROR occurred');
            System.debug('Error: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
    }
}