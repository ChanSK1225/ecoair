# EcoAir Local Data Implementation

## Scope

Flutter and Dart with Provider and sqflite. The lecturer has confirmed SQLite is sufficient for this coursework. Firebase, cloud authentication and cross-device synchronization are not required and are not implemented.

Accounts, reports, favorites, cart, orders and settings belong to this installation. Government weather requests and OpenStreetMap still require internet. SQLite is stored in Android's app-private database directory. It is not encrypted and does not protect against a rooted device or a modified application. Uninstalling can remove local data. Android automatic backup is disabled.

## Accounts and Ownership

- The users table has a stable UUID, unique normalized email, display name, encoded password hash and creation time. Email is a local identifier, not a verified email address.
- Argon2id from the cryptography package uses a fresh 16-byte random salt, 19 MiB memory, two iterations, one lane and a 32-byte output. Hash work runs in an isolate. No plaintext password or hardcoded login is stored in application source.
- Session state refers to a user ID. Changing passwords requires the old password. Google login has been removed. Forgot Password now uses a one-time password reset OTP flow. In this coursework build the OTP is shown on device as a demo email delivery step, while SQLite stores only its salted hash.
- Favorite cities and cart rows use compound owner/item primary keys. Orders are filtered by owner. User settings are namespaced by user ID.
- Community is a shared feed on this device. My Contributions filters author IDs, not display names. Scoped database operations reject attempts to modify another author's report. Likes are unique per post/user and toggle on/off.
- Each session gets new Provider instances and a new navigation tree. This prevents previous-account state and routes from remaining visible after logout.

## Migration

Schema version 5 upgrades v1/v2/v3/v4 in SQLite transactions. It preserves accounts, passwords, sessions, favorites, orders, order items, reports and likes. Old private records from pre-account versions initially belong to the locked `__legacy__` placeholder, which has no usable password and cannot log in. Old fake authentication flags are not accepted as real login sessions. The v4 migration added a nullable legacy recovery hash and a local authentication-attempt table without changing existing passwords. The v5 migration adds `password_reset_otps` for the Forgot Password OTP flow.

## Password Recovery and Forms

New UI registrations return to Login with the email filled in after the account is created. No recovery code is generated during registration and Profile no longer exposes a recovery-code setup page.

Forgot Password requires the local email, a 6-digit OTP and matching new passwords. `Send OTP` creates a fresh random OTP, stores only a salted Argon2id hash in SQLite, expires it after 10 minutes, and applies a resend cooldown. A confirmed reset atomically changes the password and consumes the OTP so it cannot be reused. Existing records keep their owner UUID. The app does not bypass ownership or delete the account during reset.

Login and password-reset checks have installation-local cooldowns after repeated failed credential checks, persisted across app restarts. This is not server-side abuse prevention and can be bypassed by someone who controls the app's private files or system clock. Wrong reset credentials use the same user-visible error regardless of whether the email exists.

Forms provide inline required/format/mismatch validation, descriptive empty-password hints, visibility toggles, loading/disabled states, error dialogs, confirmation for account creation/reset, and unsaved-entry discard confirmation. Ordinary login is not burdened with an extra confirmation. Storage errors do not expose raw SQL in the authentication dialogs.

The OTP reset flow follows the same one-time, time-limited and single-use principles as common forgot-password guidance. This is a device-local coursework implementation. To send real email from production, replace the demo delivery step with a backend or email service instead of putting SMTP/API secrets into the Flutter app.

The manual Profile > Import Legacy Data page has been removed. Legacy migration code remains only to keep old pre-account databases readable without assigning unverified records to a new user automatically.

Source and emulator data were backed up under `test_artifacts/sqlite-upgrade-before` before upgrading. Do not commit that directory: it contains private app records. The user authorized creating one new local account to receive the old data.

## CSV and Sharing

My Contributions > Export to CSV opens Export & Share. It writes a real UTF-8 CSV with a BOM in the app documents/exports/user-ID directory. The csv package quotes commas, quotes and line breaks. Formula-like user text receives a leading apostrophe to reduce spreadsheet formula execution risk. Only the active author's posts are included.

The export includes timestamps, report text, locations, coordinates, demo AQI and likes. Share CSV invokes the Android system share sheet through share_plus. WhatsApp/Telegram appear only if installed and compatible. Cancelling sharing does not delete the saved file. Do not share precise locations without considering privacy.

## Data Provenance

- Official MET Malaysia weather through data.gov.my: `https://api.data.gov.my/weather/forecast` and `https://api.data.gov.my/weather/warning`.
- Forecast requests currently use state-level records. Temperatures displayed from this feed are forecast maximums, not current measured temperatures. Fetch timestamps and cached/fetched states are separate for forecasts and warnings.
- The 56 built-in AQI locations and their AQI, humidity and wind values are demonstration/reference data. They are NOT verified live APIMS readings or proof of complete official station coverage. The APIMS portal link is an external reference, not a functioning AQI ingestion API.
- Home, map, analytics, voice, CSV and PDF identify demonstration AQI. Overall analytics aggregates included demo stations; it is not an official national AQI or historical exposure analysis.
- OpenStreetMap supplies the map tiles; attribution is retained. UI and PDF fonts are bundled locally with the Inter license.

Official real-time OR static government open data is allowed by the assignment. The weather feed is the current real government data integration. A future genuine AQI dataset must retain source, observation date, units and station IDs before replacing demo numbers. Do not describe the current AQI values as measured environmental evidence.

## Notifications and Error Handling

Android local notifications require user permission. Automatic alerts operate only after successful in-app refreshes of official warnings. They respect the per-user notification switch, optional saved-city/state text matching, expiry, deduplication and a one-hour cooldown. Warnings without a valid-until time are considered for at most 24 hours after issue. Denied notifications do not block weather display.

AQI thresholds apply only to an explicitly labelled test notification because AQI is demo data. Background polling, remote push and app-closed real-time monitoring are not implemented. A local notification is not an emergency service.

TTS reports native initialization/language/playback-start failures instead of assuming sound played. Device volume and installed voice data still need real-device verification. Store checkout uses a transaction for the order, items and cart clearing; cart persistence failures prevent checkout. Failed report saves keep the form available for retry.

## Coursework Evidence Still Requiring the Team

- Synchronize each person's Appendix D with their actual implementation. Member C can again document GPS, report CRUD, CSV file I/O and Android sharing. Confirm the team's actual module ownership rather than inventing it.
- Explain the SDG9 link as environmental information and reporting around residential/industrial areas that can support awareness and sustainable planning. Do not claim the app measures industrial emissions or proves pollution reductions.
- Prepare screenshots/main-screen PDF, presentation slides, a private repository with genuine member contributions, Appendix A, Appendix B and each member's Appendix C/D in the required formats.
- Each member must explain their own widgets, state, SQL operations, validation and algorithms during the code walkthrough. Code understanding carries 35 marks in the supplied evaluation.
- AI disclosure must accurately reflect tools used, assistance received and verification performed. Do not create false Git history, invent peer feedback or claim independent authorship of generated code.
- Check the assignment's submission formatting/comment instruction for your own source, while preserving required third-party license notices. Do not submit private test databases, credentials or backups.

## Verification Commands

Run `flutter analyze`, `flutter test`, and `flutter test integration_test/app_flow_test.dart -d <test-device> --no-uninstall`. Integration tests use a separate app-cache database; still use a dedicated emulator. Build the normal app from `lib/main.dart` after integration testing before giving the APK to users.

See the current test report in `test_artifacts/SQLITE_UPGRADE_TEST_REPORT.md` for observed results and remaining physical-device checks. A passing test suite does not guarantee a coursework grade.
