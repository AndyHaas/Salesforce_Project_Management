# Code Coverage Report

Code coverage per file for Project Management Portal classes.

**Last Updated**: Generated from latest test run  
**Overall Org Coverage**: 42%  
**Test Pass Rate**: 86% (1135 tests ran, 14% failed)

## Portal Classes

| Class Name | Coverage | Uncovered Lines | Status | Location |
|------------|----------|-----------------|--------|----------|
| `PortalMessagingController` | 61% | 96,97,140,159,181,... | ⚠️ Needs Improvement | `force-app/portal/main/default/classes/Portal/PortalMessagingController.cls` |
| `PasswordlessLoginController` | 19% | 49,52,55,60,63,... | ❌ Critical - Very Low | `force-app/portal/main/default/classes/Portal/PasswordlessLoginController.cls` |
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
- **Average Coverage** (tested classes): 40.75%
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
1. **`PasswordlessLoginController`** (19%) - Core authentication functionality
2. **`MessageNotificationScheduler`** (11%) - Email notification system
3. **`TaskSubtaskHelper`** (7%) - Task management helper
4. **`TaskProgressCalculator`** (12%) - Progress calculation
5. **`TaskDependencyHelper`** (18%) - Task dependency management

### High Priority (50-75% Coverage)
1. **`PortalMessagingController`** (61%) - Core messaging functionality
2. **`OTPCleanupScheduler`** (72%) - OTP cleanup process
3. **`ProjectTaskTrigger`** (73%) - Task trigger logic

## Recommendations

### Immediate Actions
1. **Add test coverage for `PasswordlessLoginController`**
   - Test OTP generation and validation
   - Test email sending functionality
   - Test user lookup and authentication flow

2. **Add test coverage for `MessageNotificationScheduler`**
   - Test notification sending logic
   - Test PM and Client notification flows
   - Test error handling and edge cases

3. **Add test coverage for Task Helper classes**
   - `TaskSubtaskHelper` - Test subtask creation and management
   - `TaskProgressCalculator` - Test progress calculation logic
   - `TaskDependencyHelper` - Test dependency validation and management

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
- Target coverage for production code should be 75%+ for all classes
