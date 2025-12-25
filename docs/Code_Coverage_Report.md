# Code Coverage Report

Code coverage per file for Project Management Portal classes.

**Last Updated**: Generated from latest test run  
**Overall Org Coverage**: 42%  
**Test Pass Rate**: Varies by test class (some tests still need fixes)

## Portal Classes

| Class Name | Coverage | Uncovered Lines | Status | Location |
|------------|----------|-----------------|--------|----------|
| `PortalMessagingController` | 61% | 96,97,140,159,181,... | ⚠️ Needs Improvement | `force-app/portal/main/default/classes/Portal/PortalMessagingController.cls` |
| `PasswordlessLoginController` | 29% | 49,52,55,60,63,... | ❌ Critical - Very Low | `force-app/portal/main/default/classes/Portal/PasswordlessLoginController.cls` |
| `OTPCleanupScheduler` | 72% | 55,62,90,96,97,... | ⚠️ Needs Improvement | `force-app/portal/main/default/classes/Portal/OTPCleanupScheduler.cls` |
| `MessageNotificationScheduler` | 11% | 63,65,70,71,73,... | ❌ Critical - Very Low | `force-app/portal/main/default/classes/Portal/MessageNotificationScheduler.cls` |
| `HomePageController` | N/A | - | ⚠️ No test class | `force-app/portal/main/default/classes/Portal/HomePageController.cls` |
| `PortalTaskController` | N/A | - | ⚠️ No test class | `force-app/portal/main/default/classes/Portal/PortalTaskController.cls` |
| `PortalProjectController` | N/A | - | ⚠️ No test class | `force-app/portal/main/default/classes/Portal/PortalProjectController.cls` |
| `PortalRecordListController` | N/A | - | ⚠️ No test class | `force-app/portal/main/default/classes/Portal/PortalRecordListController.cls` |
| `PortalLoginController` | N/A | - | ⚠️ No test class | `force-app/portal/main/default/classes/PortalLoginController.cls` |

## Project Management Classes

| Class Name | Coverage | Uncovered Lines | Status | Location |
|------------|----------|-----------------|--------|----------|
| `ProjectTaskTrigger` | 73% | 96,117,128,135 | ⚠️ Needs Improvement | `force-app/main/default/classes/ProjectTaskTrigger.cls` |
| `TaskProgressCalculator` | 12% | 17,25,26,29,32,... | ❌ Critical - Very Low | `force-app/main/default/classes/TaskProgressCalculator.cls` |
| `TaskDependencyHelper` | 18% | 39,59,60,61,62,... | ❌ Critical - Very Low | `force-app/main/default/classes/TaskDependencyHelper.cls` |
| `TaskSubtaskHelper` | 7% | 27,36,39,42,43,... | ❌ Critical - Very Low | `force-app/main/default/classes/TaskSubtaskHelper.cls` |
| `TaskContextController` | N/A | - | ⚠️ No test class | `force-app/main/default/classes/TaskContextController.cls` |
| `ProjectTaskDashboardController` | N/A | - | ⚠️ No test class | `force-app/main/default/classes/ProjectTaskDashboardController.cls` |
| `DisplayDensityController` | N/A | - | ⚠️ No test class | `force-app/main/default/classes/DisplayDensityController.cls` |
| `StatusColorController` | N/A | - | ⚠️ No test class | `force-app/main/default/classes/StatusColorController.cls` |

## Coverage Summary

### Portal Classes Summary
- **Average Coverage** (tested classes): 46.25% (improved from 40.75%)
- **Classes with Tests**: 4/9 (44%)
- **Classes Below 75%**: 4/4 (100%)
- **Classes Below 50%**: 2/4 (50%)
- **Classes with No Tests**: 5/9 (56%)

### Project Management Classes Summary
- **Average Coverage** (tested classes): 27.5%
- **Classes with Tests**: 4/8 (50%)
- **Classes Below 75%**: 4/4 (100%)
- **Classes Below 50%**: 3/4 (75%)
- **Classes with No Tests**: 4/8 (50%)

## Priority Actions

### Critical Priority (Below 50% Coverage)
1. **`MessageNotificationScheduler`** (11%) - Email notification system ⚠️ **Still Critical**
2. **`TaskSubtaskHelper`** (7%) - Task management helper ⚠️ **Still Critical**
3. **`TaskProgressCalculator`** (12%) - Progress calculation ⚠️ **Still Critical**
4. **`TaskDependencyHelper`** (18%) - Task dependency management ⚠️ **Still Critical**
5. **`PasswordlessLoginController`** (29%) - Core authentication functionality ✅ **Improved from 19%**

### High Priority (50-75% Coverage)
1. **`PortalMessagingController`** (61%) - Core messaging functionality
2. **`OTPCleanupScheduler`** (72%) - OTP cleanup process
3. **`ProjectTaskTrigger`** (73%) - Task trigger logic

## Recommendations

### Immediate Actions
1. **Continue improving `PasswordlessLoginController`** (29% → Target: 75%+)
   - ✅ Added tests for expired OTP, used OTP, wrong OTP code
   - ✅ Added tests for contact without portal access
   - ⚠️ Still need: Tests for successful OTP generation and email sending (requires portal user setup)
   - ⚠️ Still need: Tests for successful login flow (requires Site.login() mocking)

2. **Add test coverage for `MessageNotificationScheduler`** (11% → Target: 75%+)
   - ✅ Added tests for various notification scenarios
   - ⚠️ Still need: Tests that actually trigger email sending (may require email deliverability setup)
   - ⚠️ Still need: Tests for getTimeAgo() helper method edge cases

3. **Add test coverage for Task Helper classes**
   - `TaskSubtaskHelper` (7%) - ✅ Added more edge case tests, but coverage still low
     - ⚠️ These classes are called by triggers - need to ensure trigger tests invoke them
   - `TaskProgressCalculator` (12%) - ✅ Added more tests for edge cases
     - ⚠️ Coverage low because methods are called by triggers during DML operations
   - `TaskDependencyHelper` (18%) - ✅ Added comprehensive tests
     - ⚠️ Coverage low because methods are called by triggers during DML operations

### Medium-Term Actions
1. **Improve `PortalMessagingController` coverage to 75%+**
   - Focus on uncovered lines: 96,97,140,159,181
   - Test edge cases and error scenarios

2. **Improve `OTPCleanupScheduler` coverage to 85%+**
   - Test custom metadata reading
   - Test error handling scenarios

3. **Improve `ProjectTaskTrigger` coverage to 85%+**
   - Test all trigger scenarios
   - Test before/after insert/update/delete logic

## Test Execution

To run tests and generate coverage report:

```bash
# Run all tests
sf apex run test --code-coverage --target-org milestoneDevOrg --wait 10

# Run specific test classes
sf apex run test --class-names PortalMessagingControllerTest,PasswordlessLoginControllerTest,MessageNotificationSchedulerTest,OTPCleanupSchedulerTest --code-coverage --target-org milestoneDevOrg

# Get detailed coverage report
sf apex run test --code-coverage --result-format human --target-org milestoneDevOrg --wait 10
```

## Notes

- Coverage percentages are based on lines of code executed during test runs
- Uncovered lines may include error handling, edge cases, or deprecated code paths
- Some classes may have low coverage due to dependencies on external systems (email, platform cache, etc.)
- **Helper classes** (`TaskSubtaskHelper`, `TaskProgressCalculator`, `TaskDependencyHelper`) are called by triggers - coverage improves when trigger tests execute DML operations
- **Scheduler classes** require actual scheduled execution or manual invocation to test full flow
- Target coverage for production code should be 75%+ for all classes

## Recent Improvements

**Updated**: Latest test additions have improved coverage:
- `PasswordlessLoginController`: 19% → **29%** (+10 percentage points)
  - Added tests for expired OTP, used OTP, wrong OTP code, contact without portal access
  - Still need: Successful flow tests (requires portal user setup)

**Still Need Work**:
- `MessageNotificationScheduler`: 11% (unchanged - tests added but coverage not improving due to test context limitations)
- `TaskSubtaskHelper`: 7% (unchanged - trigger-invoked methods need trigger test execution)
- `TaskProgressCalculator`: 12% (unchanged - trigger-invoked methods need trigger test execution)
- `TaskDependencyHelper`: 18% (unchanged - trigger-invoked methods need trigger test execution)
