# Test Refactoring Plan

## Root Cause Analysis

### The Real Problem

**Tests ARE executing correctly** - they use DML operations which trigger `ProjectTaskTrigger`, which then calls the helper methods. However, **coverage is still low** because:

1. **Conditional Logic Not Fully Exercised**: Helper methods have many conditional branches that require specific data setups
2. **Edge Cases Not Tested**: Some code paths (null checks, empty collections, missing data) aren't being tested
3. **Some Tests May Be Redundant**: Multiple tests may be testing the same scenario
4. **Missing Test Scenarios**: Some code paths simply aren't being exercised

### Example: TaskSubtaskHelper.populateSubtaskUsers()

**Code Structure**:
```apex
for (Project_Task__c task : tasks) {
    if (task.Parent_Task__c != null) {           // Line 26 - Always tested
        parentTaskIds.add(task.Parent_Task__c);
    }
}
// ... query parentTasksMap ...
for (Project_Task__c task : tasks) {
    if (task.Parent_Task__c != null) {           // Line 43 - Always tested
        Project_Task__c parentTask = parentTasksMap.get(task.Parent_Task__c);
        if (parentTask != null) {                // Line 44 - May not be tested if parent always exists
            if (task.Client_User__c == null) {   // Line 46 - May not be tested if Client_User__c is always set
                task.Client_User__c = parentTask.Client_User__c;
            }
        }
    }
}
```

**Current Test Coverage**: 7%
- ✅ Tests insert subtasks (triggers the method)
- ⚠️ May not test: `parentTask == null` scenario (line 44)
- ⚠️ May not test: `task.Client_User__c != null` scenario (line 46 - when Client_User__c is already set)

## Issues Identified

### 1. Tests Call Methods Directly (Some Cases)

**Found**: Some tests call helper methods directly instead of using DML:
```apex
// TaskSubtaskHelperTest.cls - Line 144
TaskSubtaskHelper.populateSubtaskUsers(new List<Project_Task__c>()); // Direct call
```

**Issue**: While this tests edge cases (empty list), it doesn't test the trigger integration.

**Recommendation**: Keep these for edge case testing, but ensure main tests use DML.

### 2. Missing Test Scenarios

**TaskSubtaskHelper** needs tests for:
- ✅ Subtask with parent (covered)
- ❌ Subtask where parent doesn't exist in map (line 44: `parentTask == null`)
- ❌ Subtask where `Client_User__c` is already set (line 46: `task.Client_User__c != null`)
- ❌ Multiple subtasks with same parent (partially covered)

**TaskProgressCalculator** needs tests for:
- ✅ Basic progress calculation (covered)
- ❌ Parent task not found in map (line 52: `parentTask == null`)
- ❌ Parent task missing Account or Priority (lines 57-58: early return)
- ❌ Subtasks list is empty for parent (line 47: `parentSubtasks == null || isEmpty()`)

**TaskDependencyHelper** needs tests for:
- ✅ Basic dependency assessment (covered)
- ❌ Tasks with no relationships (partially covered)
- ❌ Complex dependency chains

### 3. Redundant Tests

**Potential Redundancy**:
- Multiple tests checking the same scenario with slight variations
- Tests that don't actually exercise different code paths

**Action Needed**: Review each test method to ensure it tests a unique scenario.

## Refactoring Strategy

### Phase 1: Analyze Current Tests

1. **Map each test method to code paths it exercises**
2. **Identify gaps** - code paths not covered by any test
3. **Identify redundancy** - multiple tests covering the same path
4. **Identify unused tests** - tests that don't actually execute the helper code

### Phase 2: Add Missing Tests

1. **Add tests for uncovered code paths**:
   - Null/empty checks
   - Edge cases
   - Error conditions
   - Boundary conditions

2. **Ensure tests use DML** (not direct calls) for integration testing:
   ```apex
   // GOOD - Uses DML, triggers the trigger
   insert subtask;
   
   // ALSO GOOD - Direct call for edge case testing
   TaskSubtaskHelper.populateSubtaskUsers(new List<Project_Task__c>());
   ```

### Phase 3: Remove/Consolidate Redundant Tests

1. **Identify tests that test the same scenario**
2. **Consolidate** into a single comprehensive test
3. **Remove** tests that don't add value

### Phase 4: Verify Coverage Improvement

1. **Run tests** and check coverage
2. **Verify** all code paths are exercised
3. **Target**: 75%+ coverage for all helper classes

## Specific Recommendations

### TaskSubtaskHelper (7% → Target: 75%+)

**Add Tests For**:
1. `parentTask == null` in `populateSubtaskUsers()` (line 44)
2. `task.Client_User__c != null` (already set) in `populateSubtaskUsers()` (line 46)
3. `oldTask == null` in `updateParentTaskStatus()` (line 68)
4. `parentTask == null` in `updateParentTaskStatus()` (line 113)
5. `subtasks == null || isEmpty()` in `updateParentTaskStatus()` (line 123)
6. `hasInProgressSubtask` and `hasPendingSubtask` combinations (lines 128-137)

**Keep Tests**:
- All DML-based tests (integration testing)
- Edge case tests (empty lists, null checks)

**Consider Removing**:
- Tests that are exact duplicates of other tests
- Tests that don't actually exercise any code

### TaskProgressCalculator (12% → Target: 75%+)

**Add Tests For**:
1. `parentTask == null` (line 52)
2. `parentTask.Account__c == null` (line 57)
3. `parentTask.Priority__c == null` (line 57)
4. `parentSubtasks == null || isEmpty()` (line 47)
5. All subtasks removed (zero valid subtasks)

**Keep Tests**:
- All DML-based tests
- Tests for different calculation scenarios

### TaskDependencyHelper (18% → Target: 75%+)

**Add Tests For**:
1. `tasksMap` building logic (line 18-21)
2. `relatedTaskIds.isEmpty()` scenarios (line 52)
3. `dependentRelationships.isEmpty()` scenarios
4. `tasksToCheckBlocking.isEmpty()` scenarios (line 179)
5. Complex dependency chains with multiple levels

**Keep Tests**:
- All comprehensive dependency tests
- Tests for different status combinations

## Implementation Plan

### Step 1: Create Test Coverage Map

For each helper class, create a map showing:
- Each line of code
- Which test(s) exercise that line
- Which lines are not covered

### Step 2: Add Targeted Tests

Add tests specifically designed to exercise uncovered lines:
```apex
@isTest
static void testPopulateSubtaskUsers_ParentNotInMap() {
    // Test scenario where parentTask == null (line 44)
    // Create subtask with parent ID that doesn't exist in query results
}

@isTest
static void testPopulateSubtaskUsers_ClientUserAlreadySet() {
    // Test scenario where task.Client_User__c != null (line 46)
    // Create subtask with Client_User__c already populated
}
```

### Step 3: Review and Consolidate

Review all test methods and:
1. Remove exact duplicates
2. Consolidate similar tests
3. Ensure each test has a clear, unique purpose

### Step 4: Verify

Run tests and verify coverage improvement.

## Conclusion

**Yes, we should refactor tests**, but the issue is:

1. **Redundant Tests**: Multiple tests testing the same scenario (e.g., 3 tests all inserting subtask with parent)
2. **Misnamed Tests**: Tests that claim to test scenarios they don't actually test (e.g., "ExistingOwnerId" test doesn't set Client_User__c)
3. **Missing Tests**: Code paths that aren't being exercised (null checks, edge cases)

**The current test structure (using DML to trigger the trigger) is CORRECT**. We need to:

1. **Remove redundant tests** - Keep one test per unique scenario
2. **Fix misnamed tests** - Make them actually test what their name suggests
3. **Add missing tests** - Cover all conditional branches and edge cases

**Recommendation**: Refactor to remove redundancy and add missing scenarios, rather than a complete rewrite.
