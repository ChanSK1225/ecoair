# EcoAir Improvement Roadmap

These are proposed next steps, not features claimed as implemented by this update.

## Priority 1: Data Quality and Clear Meaning

- Replace demonstration AQI with a verified government dataset, including station IDs, observation time, units, source and coverage. A properly dated official static dataset is preferable to presenting made-up values as live.
- Keep forecast maximum temperatures separate from current observations. Show data age and a stale-data badge independently for each feed.
- Do not connect unrelated station readings with a line that could be mistaken for a time trend. Use a ranked horizontal station chart for a snapshot; add a time-series chart only after storing dated observations.

## Priority 2: Consistent Failure Recovery

- Standardize timeout, offline, server throttling and corrupt-response states across weather, map tiles, location and exports, with contextual retry buttons.
- Retain report drafts and checkout form entries when the app closes unexpectedly. Offer explicit discard rather than losing partially entered content.
- Add an app-private storage status screen, encrypted backup/export and validated restore preview. Never implement backup by copying plaintext credentials or silently overwriting the database.

## Priority 3: Mobile Usability

- Improve chart tooltip readability and give charts a concise accessible text summary.
- Add searchable station filters and a consistent selected-region label across Home, Map, Analytics and exported reports.
- Verify all pages with TalkBack, larger system fonts, small phones, landscape and keyboard open. Keep bottom actions clear of navigation and system insets.
- Replace unnecessary modal dialogs with inline feedback for ordinary actions; retain confirmation for destructive changes, checkout and security-sensitive actions.

## Priority 4: Useful Coursework Features

- Community: category, draft saving, time filter and report-resolution status, with GPS accuracy/time shown when useful.
- Store: local order cancellation while still Processing and a clear simulation label for payment/tracking. Do not imply real courier updates.
- Analytics: select a date range from stored real observations, export exactly that range and disclose incomplete dates.
- Security: optional biometric re-unlock of the local session, explicit account deletion with an export reminder, and secure handling of exported precise coordinates.

## Before Submission

Run a physical-phone checklist for GPS/address lookup, audible TTS, notification permission denial/re-grant, keyboard layouts, offline restart and CSV sharing to installed apps. Each member should be able to explain the database ownership rules and the code they present. A working app still needs accurate team forms, screenshots, presentation evidence and genuine contribution history.
