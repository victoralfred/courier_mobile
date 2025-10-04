# Technical Improvements Tracker

This document tracks all improvement opportunities identified during the comprehensive code documentation initiative. All improvements are categorized by priority and area.

**Total Improvements Identified:** 326
- **High Priority:** 85 items
- **Medium Priority:** 140 items
- **Low Priority:** 101 items

---

## 🔴 High Priority (85 items)

### Network & API Layer (15 items)

#### CSRF & Authentication
- [ ] Remove debug print statements in CsrfTokenManager (use logging service)
- [ ] Remove debug print statements in CsrfInterceptor (use logging service)
- [ ] Remove debug print statements in AuthInterceptor (use logging service)
- [ ] Make certificatePinner and csrfTokenManager required for production
- [ ] Add token expiry check before injection in AuthInterceptor

#### Request Handling
- [ ] Add request retry mechanism with exponential backoff for network failures
- [ ] Implement request queuing for offline mode
- [ ] Add mutex/lock to prevent concurrent token refresh attempts
- [ ] Queue failed requests and retry after successful refresh
- [ ] Store request ID in context for error reporting
- [ ] Return request ID from RequestInterceptor for error correlation
- [ ] Add structured logging for errors (track error rates, patterns)

#### API Client
- [ ] Add request retry mechanism with exponential backoff
- [ ] Implement request queuing for offline mode (currently at repository level)

### Authentication Layer (25 items)

#### Login & Registration
- [ ] Remove debug print statements in LoginBloc (use logging service)
- [ ] Add remember me functionality (persistent login)
- [ ] Add rate limiting (prevent brute force attacks)
- [ ] Complete OAuth flow implementation (browser launch + callback handling)
- [ ] Add email verification step (send verification code)
- [ ] Add phone verification step (SMS OTP)

#### Password & Security
- [ ] Add password confirmation validation in Register use case
- [ ] Add password complexity validation (uppercase, numbers, symbols)
- [ ] Implement token refresh mutex (prevent concurrent refreshes)
- [ ] Add refresh retry with exponential backoff

#### OAuth & PKCE
- [ ] Add configurable code verifier length in GeneratePkceChallenge
- [ ] Add nonce support for OpenID Connect in AuthorizeOAuth
- [ ] Add JWT token validation in ExchangeCodeForToken
- [ ] Implement automatic token refresh in ExchangeCodeForToken

### Driver Features (12 items)

#### Driver Entity & Validation
- [ ] Add email verification status field to Driver entity
- [ ] Add phone verification status field to Driver entity
- [ ] Implement Nigerian plate number format validation (ABC-123-XY)
- [ ] Add vehicle registration number field to VehicleInfo
- [ ] Add truck type to VehicleType for commercial freight

#### Repository & Operations
- [ ] Add batch operations for multiple drivers in DriverRepository
- [ ] Add driver search/filter by status, rating, location radius
- [ ] Extract backend sync logic to separate SyncService in DriverRepositoryImpl
- [ ] Add retry logic for failed sync operations with exponential backoff
- [ ] Add toBackendJson() method in DriverMapper for PUT/POST requests

### Database Layer (20 items)

#### Schema & Integrity
- [ ] Add database integrity checks on app startup
- [ ] Add database encryption for sensitive data (tokens, personal info)
- [ ] Encrypt accessToken and refreshToken fields in UserTable
- [ ] Add composite index on (status, availability) in DriverTable for faster matching
- [ ] Add composite indexes on (userId, status) and (driverId, status) in OrderTable
- [ ] Add index on createdAt in OrderTable for time-based queries
- [ ] Refactor OrderItemTable to support multiple items per order (1:N relationship)

#### Sync & Operations
- [ ] Implement exponential backoff for retry attempts in SyncQueueTable
- [ ] Add priority field for critical operations in SyncQueueTable
- [ ] Add batch sync support to reduce API calls in SyncQueueTable
- [ ] Add operation dependencies in SyncQueueTable (e.g., create before update)
- [ ] Add getDriversNearLocation() in DriverDAO for proximity matching
- [ ] Add stale location check for inactive drivers in DriverDAO
- [ ] Add pagination support for large order lists in OrderDAO
- [ ] Optimize getActiveOrders() with composite index in OrderDAO

### Security Services (13 items)

#### Encryption & Hashing
- [ ] Implement key rotation strategy for long-lived data
- [ ] Add encryption/decryption monitoring and error logging
- [ ] Implement PBKDF2 or Argon2 for password hashing (SHA-256+salt vulnerable)
- [ ] Add data integrity verification (HMAC) for tamper detection
- [ ] Implement constant-time hash comparison (prevent timing attacks)

#### Session & Certificate Management
- [ ] Add server-side session validation (prevent clock manipulation)
- [ ] Add absolute session timeout (prevent infinite sessions)
- [ ] Add certificate expiration monitoring in CertificatePinner
- [ ] Implement certificate rotation without app update (remote config with signature)
- [ ] Remove debug print statements in CertificatePinner (sensitive hashes exposed)

---

## 🟡 Medium Priority (140 items)

### Network & API Layer (28 items)

#### Performance & Reliability
- [ ] Add metrics/analytics for API performance monitoring
- [ ] Implement request deduplication to prevent duplicate in-flight requests
- [ ] Consider using dependency injection container in ApiClient
- [ ] Implement exponential backoff for token refresh retries
- [ ] Add resume capability for interrupted downloads
- [ ] Add retry logic for transient errors (500, 502, 503) in ErrorInterceptor
- [ ] Add custom error handling per endpoint in ErrorInterceptor
- [ ] Add configurable retry on CSRF fetch failure
- [ ] Cache CSRF token for 5-10 minutes in CsrfInterceptor
- [ ] Add token caching with 5-10 minute TTL in CsrfTokenManager
- [ ] Add retry logic in CsrfTokenManager (currently fails on first error)

#### Headers & Tracking
- [ ] Add request correlation chain (parent request ID for nested calls)
- [ ] Add app version and build number headers
- [ ] Add request ID to logs and error reports
- [ ] Add caching for parsed errors in ErrorInterceptor
- [ ] Use regex or exact matching instead of contains in CsrfInterceptor
- [ ] Support multiple auth schemes (Bearer, Basic, API Key) in AuthInterceptor
- [ ] Add token expiry check before injection in AuthInterceptor

#### Connectivity & Sync
- [ ] Add configurable sync intervals in ConnectivityService
- [ ] Add sync retry with exponential backoff in ConnectivityService
- [ ] Add network quality metrics (bandwidth, latency) in ConnectivityService
- [ ] Add manual sync trigger capability in ConnectivityService
- [ ] Add connectivity state persistence in ConnectivityService
- [ ] Implement circuit breaker pattern in ConnectivityService

### Authentication Layer (35 items)

#### Use Cases & Validation
- [ ] Add email uniqueness check before submission in Register use case
- [ ] Add password complexity validation in Register use case
- [ ] Add password complexity validation in Login use case
- [ ] Add rate limiting in Login use case

#### Token & Session Management
- [ ] Add token expiry notification (warn before expiration)
- [ ] Support multiple token types (OAuth, API keys)
- [ ] Add configurable refresh window in TokenManager

#### OAuth & Providers
- [ ] Add verifier/challenge validation in GeneratePkceChallenge
- [ ] Support 'plain' method (non-S256) in GeneratePkceChallenge
- [ ] Add custom scope validation in AuthorizeOAuth
- [ ] Check provider availability before authorization in AuthorizeOAuth
- [ ] Add token revocation support in ExchangeCodeForToken
- [ ] Implement configurable token storage in ExchangeCodeForToken

#### Registration & Onboarding
- [ ] Add phone formatter (auto-format as user types) in RegistrationBloc
- [ ] Add terms and conditions dialog/web view in RegistrationBloc
- [ ] Add phone normalization unit tests in RegistrationBloc
- [ ] Add referral code support in RegistrationBloc
- [ ] Add profile picture upload during registration in RegistrationBloc

#### Domain Entities
- [ ] Add email verification status field to User entity
- [ ] Add phone verification status field to User entity
- [ ] Add last login timestamp to User entity
- [ ] Add driver documents (license, insurance, vehicle registration) to Driver entity
- [ ] Add driver performance metrics to Driver entity
- [ ] Add preferred delivery zones/areas to Driver entity

### Driver Features (25 items)

#### Status & Availability
- [ ] Add on_break status to AvailabilityStatus for temporary unavailability
- [ ] Add inactive status to DriverStatus for long-term dormant drivers

#### Vehicle Information
- [ ] Add insurance details (policy number, expiry) to VehicleInfo
- [ ] Add vehicle inspection certificate to VehicleInfo
- [ ] Add tricycle (keke) type to VehicleType for Nigerian market

#### Repository & Operations
- [ ] Add driver statistics (total deliveries, acceptance rate) in DriverRepository
- [ ] Add driver document upload/management in DriverRepository
- [ ] Add driver performance metrics in DriverRepository
- [ ] Add conflict resolution for concurrent updates in DriverRepositoryImpl
- [ ] Add batch sync operations in DriverRepositoryImpl

#### Data Mapping
- [ ] Add validation during mapping in DriverMapper
- [ ] Add error handling for malformed data in DriverMapper

### Database Layer (35 items)

#### Indexes & Performance
- [ ] Add index on email in UserTable for faster login lookups
- [ ] Add lastActiveAt timestamp to DriverTable for inactive driver identification
- [ ] Add composite index on (status, availability) in DriverTable
- [ ] Add spatial index on (currentLatitude, currentLongitude) for proximity searches
- [ ] Add estimatedDeliveryTime field to OrderTable for ETA tracking
- [ ] Add distance field to OrderTable for analytics

#### Data Model Enhancements
- [ ] Add documentsVerified JSON field to DriverTable
- [ ] Add fragile boolean flag to OrderItemTable
- [ ] Add specialInstructions field to OrderItemTable
- [ ] Add maxRetries limit in SyncQueueTable to prevent infinite loops
- [ ] Add conflict resolution strategy in SyncQueueTable

#### DAO Operations
- [ ] Add updateRatingWithNewReview() atomic operation in DriverDAO
- [ ] Add validation for Nigeria geographic bounds in DriverDAO
- [ ] Add getOrdersByDateRange() in OrderDAO for analytics
- [ ] Add cancelOrder() method with reason in OrderDAO
- [ ] Cache joined order+item queries in OrderDAO
- [ ] Add getUserByEmail() in UserDAO
- [ ] Add validation for required fields before serialization in OrderTableExtensions
- [ ] Add validation for Nigeria phone format in DriverTableExtensions
- [ ] Validate geographic bounds in DriverTableExtensions

### Security Services (17 items)

#### Encryption & Session
- [ ] Implement PBKDF2 or Argon2 for password hashing
- [ ] Add HMAC for data integrity verification
- [ ] Add session fingerprinting (detect device transfer)
- [ ] Add session recovery on app crash
- [ ] Implement grace period for network issues in SessionManager

#### Certificate & Obfuscation
- [ ] Implement public key pinning as alternative in CertificatePinner
- [ ] Add Certificate Transparency (CT) log verification in CertificatePinner
- [ ] Make development allow-all behavior configurable in CertificatePinner
- [ ] Add partial email masking in DataObfuscator
- [ ] Implement configurable masking strategies in DataObfuscator
- [ ] Add pattern detection for SSN, passport numbers in DataObfuscator

---

## 🟢 Low Priority (101 items)

### Network & API Layer (20 items)

#### Features & Extensions
- [ ] Add request cancellation support using CancelToken groups
- [ ] Consider adding GraphQL support alongside REST
- [ ] Consider making validateStatus more restrictive in ApiClient
- [ ] Emit stream event for UI "refreshing session" message
- [ ] Implement file integrity verification (checksum)
- [ ] Add device/platform headers (OS, device model)
- [ ] Add user ID header for authenticated requests
- [ ] Add metrics for error tracking (Sentry, Firebase Crashlytics)
- [ ] Support circuit breaker pattern in ErrorInterceptor
- [ ] Support multiple error formats in ErrorInterceptor
- [ ] Add metrics for CSRF success/failure rates
- [ ] Support custom header name in CsrfInterceptor
- [ ] Add metrics for token fetch rates in CsrfTokenManager
- [ ] Implement token pre-fetching on app start in CsrfTokenManager
- [ ] Log errors even when returning null in CsrfTokenManager
- [ ] Add metrics for auth header injection in AuthInterceptor
- [ ] Support conditional auth (some endpoints don't need auth) in AuthInterceptor
- [ ] Add retry on 401 before giving up in AuthInterceptor
- [ ] Add sync conflict metrics in ConnectivityService
- [ ] Add background sync worker integration in ConnectivityService

### Authentication Layer (28 items)

#### User Experience
- [ ] Add remember me functionality in Login use case
- [ ] Add terms and conditions acceptance validation in Register use case
- [ ] Add referral code support in Register use case
- [ ] Add social account linking in LoginBloc
- [ ] Add login analytics (track success/failure rates) in LoginBloc
- [ ] Add social registration (Google, Apple) in RegistrationBloc
- [ ] Add registration analytics (track conversion funnel) in RegistrationBloc
- [ ] Add country code selector in RegistrationBloc
- [ ] Extract to separate validator class in RegistrationBloc

#### Token & Session
- [ ] Add token metrics (refresh count, failure rate) in TokenManager
- [ ] Add configurable expiry in GeneratePkceChallenge
- [ ] Support custom hash algorithms in GeneratePkceChallenge
- [ ] Add analytics tracking in AuthorizeOAuth
- [ ] Add configurable request expiry in AuthorizeOAuth
- [ ] Add analytics tracking in ExchangeCodeForToken

#### Domain Entities
- [ ] Add profile photo URL to User entity
- [ ] Add user preferences/settings to User entity
- [ ] Add multilingual support for rejection reasons to Driver entity

### Driver Features (18 items)

#### Vehicle & Capacity
- [ ] Add vehicle capacity (weight, dimensions) to VehicleInfo
- [ ] Add vehicle photo URLs to VehicleInfo
- [ ] Add fuel type field to VehicleInfo
- [ ] Add electric vehicle type to VehicleType
- [ ] Add scooter type to VehicleType

#### Repository & Analytics
- [ ] Add driver preferences management in DriverRepository
- [ ] Add driver availability schedule (recurring hours) in DriverRepository
- [ ] Add driver data versioning in DriverRepositoryImpl
- [ ] Add sync progress callbacks in DriverRepositoryImpl
- [ ] Add mapper for partial updates (PATCH) in DriverMapper
- [ ] Add mapper performance metrics in DriverMapper

### Database Layer (25 items)

#### Schema Extensions
- [ ] Add profileImageUrl field to UserTable
- [ ] Add metadata field (JSON) for extensibility to UserTable
- [ ] Add totalDeliveries counter to DriverTable
- [ ] Add vehicleCapacity field to DriverTable
- [ ] Add cancellationReason field to OrderTable
- [ ] Add customerNotes and driverNotes fields to OrderTable
- [ ] Add imageUrl field to OrderItemTable
- [ ] Add dimensions (length, width, height) to OrderItemTable
- [ ] Add sync statistics to SyncQueueTable
- [ ] Add syncedAt timestamp to SyncQueueTable

#### Database Management
- [ ] Implement database backup/restore functionality
- [ ] Add database size monitoring and cleanup strategies
- [ ] Implement database vacuum on app idle

#### DAO Extensions
- [ ] Add getDriverStatistics() in DriverDAO
- [ ] Add getDriversByStatus() in DriverDAO
- [ ] Add getOrderStatistics() in OrderDAO
- [ ] Add searchOrders() in OrderDAO
- [ ] Add getRecentUsers() for multi-account support in UserDAO
- [ ] Add updateProfile() for partial updates in UserDAO
- [ ] Add lastLoginAt tracking in UserDAO
- [ ] Add fromJson() factory methods in OrderTableExtensions
- [ ] Add toUpdateJson() for partial updates in OrderTableExtensions
- [ ] Add toLocationUpdateJson() in DriverTableExtensions

### Security Services (10 items)

#### Encryption & Storage
- [ ] Support AES-GCM/ChaCha20-Poly1305 in EncryptionService
- [ ] Implement secure memory wiping in EncryptionService

#### Session & Authentication
- [ ] Add biometric re-authentication for sensitive operations in SessionManager
- [ ] Track concurrent sessions per user in SessionManager

#### Certificate & Monitoring
- [ ] Add pinning failure metrics in CertificatePinner
- [ ] Support OCSP stapling verification in CertificatePinner

#### Data Protection
- [ ] Support custom regex patterns in DataObfuscator
- [ ] Add obfuscation metrics in DataObfuscator

---

## 📋 Implementation Guidelines

### Priority Definitions

**High Priority (🔴):**
- Security vulnerabilities
- Performance bottlenecks
- Critical functionality gaps
- Production blockers
- Data integrity issues

**Medium Priority (🟡):**
- User experience enhancements
- Code maintainability improvements
- Additional validation
- Monitoring and observability
- Non-critical feature additions

**Low Priority (🟢):**
- Nice-to-have features
- Future optimizations
- Analytics and metrics
- Developer convenience tools
- Experimental features

### Implementation Approach

1. **Review & Prioritize:** Review all High Priority items first
2. **Create Issues:** Create GitHub/JIRA issues for tracking
3. **Sprint Planning:** Include in sprint planning based on priority
4. **Test Coverage:** Ensure adequate test coverage for each improvement
5. **Documentation:** Update documentation after implementation
6. **Code Review:** Require code review for all security-related changes

---

## 📊 Progress Tracking

**Completed:** 0/326
**In Progress:** 0/326
**Blocked:** 0/326

### By Priority
- High: 0/85 (0%)
- Medium: 0/140 (0%)
- Low: 0/101 (0%)

### By Area
- Network & API: 0/63 (0%)
- Authentication: 0/88 (0%)
- Driver Features: 0/55 (0%)
- Database: 0/80 (0%)
- Security: 0/40 (0%)

---

*Last Updated: 2025-10-04*
*Documentation Initiative: Complete*
*Total Items: 326*
