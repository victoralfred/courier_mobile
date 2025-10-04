# Code Documentation Guide

## Documentation Standards for Courier App

### Purpose
This guide ensures all code is properly documented with clear explanations of WHAT the code does, WHY it's implemented that way, and WHERE improvements can be made.

## Documentation Template

### For Classes
```dart
/// [ClassName] - Brief one-line description
///
/// **What it does:**
/// - Detailed explanation of the class purpose
/// - Key responsibilities
///
/// **Why it exists:**
/// - Business/technical rationale
/// - Problem it solves
///
/// **Usage Example:**
/// ```dart
/// final instance = ClassName(
///   param1: value1,
///   param2: value2,
/// );
/// final result = await instance.method();
/// ```
///
/// **IMPROVEMENT:** [If applicable]
/// - Potential enhancements
/// - Performance optimizations
/// - Architectural improvements
class ClassName {
  // Implementation
}
```

### For Methods/Functions
```dart
/// [methodName] - Brief description
///
/// **What it does:**
/// - Step-by-step explanation
/// - Input/output behavior
///
/// **Why:**
/// - Business logic rationale
/// - Technical decisions
///
/// **Parameters:**
/// - [param1]: Description and constraints
/// - [param2]: Description and constraints
///
/// **Returns:**
/// - Description of return value/type
///
/// **Throws:**
/// - [ExceptionType]: When and why
///
/// **Example:**
/// ```dart
/// final result = await methodName(
///   param1: 'value',
///   param2: 123,
/// );
/// ```
///
/// **IMPROVEMENT:** [If applicable]
/// - Optimization opportunities
Future<ReturnType> methodName(Type param1, Type param2) async {
  // Implementation
}
```

### For Interceptors
```dart
/// [InterceptorName] - Brief description
///
/// **What it does:**
/// - Request/response modification
/// - When it triggers
///
/// **Why:**
/// - Security/functionality rationale
/// - Integration requirements
///
/// **Flow:**
/// 1. Step 1
/// 2. Step 2
/// 3. Step 3
///
/// **Example:**
/// ```dart
/// final dio = Dio()
///   ..interceptors.add(InterceptorName(dependency));
/// ```
///
/// **IMPROVEMENT:** [If applicable]
class InterceptorName extends Interceptor {
  // Implementation
}
```

### For Value Objects
```dart
/// [ValueObjectName] - Brief description
///
/// **What it does:**
/// - Encapsulates specific domain concept
/// - Validation rules
///
/// **Why:**
/// - Type safety
/// - Domain modeling
///
/// **Validation:**
/// - Rule 1
/// - Rule 2
///
/// **Example:**
/// ```dart
/// final email = Email('user@example.com');
/// if (email.isValid) {
///   // Use email
/// }
/// ```
///
/// **IMPROVEMENT:** [If applicable]
class ValueObjectName {
  // Implementation
}
```

### For Repositories
```dart
/// [RepositoryName] - Brief description
///
/// **What it does:**
/// - Data access abstraction
/// - Offline-first pattern implementation
///
/// **Why:**
/// - Clean Architecture separation
/// - Testability
///
/// **Data Flow:**
/// 1. Check local database
/// 2. Return cached data if available
/// 3. Fetch from API if needed
/// 4. Update local cache
///
/// **Example:**
/// ```dart
/// final repository = RepositoryName(database, apiClient);
/// final result = await repository.getData(id);
/// result.fold(
///   (failure) => handleError(failure),
///   (data) => handleSuccess(data),
/// );
/// ```
///
/// **IMPROVEMENT:** [If applicable]
class RepositoryName implements IRepositoryName {
  // Implementation
}
```

### For BLoCs
```dart
/// [BlocName] - Brief description
///
/// **What it does:**
/// - State management for [feature]
/// - Business logic coordination
///
/// **Why:**
/// - Separation of concerns
/// - Reactive state management
///
/// **Events:**
/// - [Event1]: When to dispatch
/// - [Event2]: When to dispatch
///
/// **States:**
/// - [State1]: What it represents
/// - [State2]: What it represents
///
/// **Example:**
/// ```dart
/// BlocProvider(
///   create: (_) => BlocName(useCase1, useCase2)
///     ..add(InitialEvent()),
///   child: ChildWidget(),
/// )
/// ```
///
/// **IMPROVEMENT:** [If applicable]
class BlocName extends Bloc<Event, State> {
  // Implementation
}
```

## Flags for Code Quality

### IMPROVEMENT Flag
Use when you identify:
- Performance optimization opportunities
- Better architectural approaches
- Code simplification possibilities
- Missing error handling
- Potential bugs or edge cases
- Tech debt

**Format:**
```dart
/// **IMPROVEMENT:**
/// - [Priority: High/Medium/Low] Description of improvement
/// - Example: Could use memoization to cache results
/// - Rationale: Why this would be better
```

### TODO Flag
Use for planned enhancements:
```dart
/// **TODO:**
/// - [ ] Feature to implement
/// - [ ] Test to add
/// - [ ] Refactoring needed
```

### DEPRECATED Flag
Use for code planned for removal:
```dart
/// **DEPRECATED:**
/// - Will be removed in version X.X
/// - Use [NewApproach] instead
/// - Migration guide: [link or description]
```

## Documentation Priority

### High Priority (Document First)
1. Public APIs and interfaces
2. Complex business logic
3. Security-critical code
4. Interceptors and middleware
5. Repository implementations
6. BLoC implementations

### Medium Priority
1. Use cases
2. Mappers
3. Data sources
4. Widgets with complex logic
5. Utility classes

### Low Priority
1. Simple getters/setters
2. DTOs with obvious fields
3. Generated code
4. Test files (comment on test scenarios instead)

## Review Checklist

Before committing, ensure:
- [ ] All public classes have class-level documentation
- [ ] All public methods have method-level documentation
- [ ] Complex private methods are documented
- [ ] IMPROVEMENT flags added where applicable
- [ ] Examples provided for non-obvious usage
- [ ] WHY is explained, not just WHAT

## Tools

### Dart Doc Generation
```bash
# Generate documentation
dart doc .

# View locally
cd doc/api
python3 -m http.server 8000
```

### IDE Support
- VS Code: Use `///` to trigger doc comment template
- Android Studio: Use `/** */` and press Enter

## Examples

See these files for reference:
- `lib/core/network/api_client.dart` - Comprehensive API client docs
- `lib/features/auth/domain/entities/user.dart` - Entity documentation
- `lib/features/driver/status/presentation/blocs/driver_status_bloc.dart` - BLoC documentation
