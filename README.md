# Mosaic by MPC Markets — Stage 1 mobile demo

Interactive Flutter demo of the Mosaic client app for iOS and Android, with a Flutter web preview
for sharing in a browser. **All client, portfolio and market data is fictional.** Approvals,
adviser replies and alerts are simulated. No order can be placed from the app.

Fixed demo timeline: market data is "as at Tue 20 Oct 2026, 4:20 pm AEDT, 20 min delayed".

## What the demo covers

| Area | Included |
| --- | --- |
| Login | Branded sign-in, Explore Demo, forgot password, FSG / Terms / Privacy, no registration |
| Session | Biometric opt-in, lock screen (simulated on web), 5 min background lock, 30 min inactivity sign-out, token-expiry simulation, secure logout |
| Home | Portfolio card, allocation donut, entity cards, total cash, top 5 holdings, CSL recommendation, research, recent trades, AFSL footer |
| Markets | Delayed market strip, Morning Call and Bulls vs. Bears, featured research, movers, filtered and paginated content, podcast player, video player |
| Holdings | Summary, holdings grouped by entity, entity detail (Equities / Structured / Cash), watchlist with search, add, remove, alerts |
| Quote | Delayed price with as-at time, 1D / 1M / 3M / 1Y chart with previous close, stats grid, watchlist, alerts, Ask Adviser, ASX announcements with K.ai summary |
| Recs | Four product cards, pending approvals, detail, accept and decline confirmation sheets, audit, status updates, structured offers with Register Interest |
| Messages | Pinned static K.ai preview, adviser and desk threads, chat with receipts, typing indicator, drafts, failed-send retry, shared recommendation cards |
| Alerts | Alert settings sheet, per-security alerts, notification history, demo simulator with in-app banners and deep links |
| Settings | Profile, notifications, biometrics, Light / System / Dark, device protections, demo tools, legal, contact, account closure request, version, logout |

## Run locally

Requires Flutter 3.24 or newer.

```bash
flutter pub get
flutter run -d chrome          # web preview
flutter run                    # attached iOS simulator or Android emulator
flutter test                   # unit and widget tests
```

## Deploy the web preview to Vercel

Vercel does not build Flutter itself, so build locally and deploy the static output.

```bash
flutter build web --release
npx vercel deploy build/web --prod
```

The first deploy asks you to log in and name the project. The app uses hash URLs, so no rewrite
rules are needed. `web/vercel.json` is copied into the build and sets caching headers.

## Project structure

```
lib/
  core/      theme.dart (brand tokens, light/dark), format.dart (AUD, %, Australia/Sydney time)
  data/      models.dart (typed models), seed.dart (fictional data), repository.dart (mock + live)
  state/     providers.dart (Riverpod: session, portfolio, watchlist, recs, offers, chat, alerts)
  ui/        login, home, markets, holdings, quote, recs, messages, settings, widgets (components)
  main.dart  GoRouter with five independent tab stacks, tab shell, lock overlay, phone frame
test/        logic_test.dart (reconciliation, flows, errors), widget_test.dart (navigation, a11y)
```

## Architecture

- **Repository contract.** `MosaicRepository` has two implementations. `MockMosaicRepository`
  serves seeded data with latency, persistence and configurable failures.
  `LiveMosaicRepository` is the Dio adapter with bearer-token and refresh interceptors. Its
  endpoint paths are placeholders until MPC supplies API documentation.
- **Mosaic is the system of record.** The app holds no financial state of its own. Every
  approval waits for repository acknowledgement before the UI changes.
- **Chat transport.** `ChatTransport` is the seam for a WebSocket connection, with
  `PollingChatTransport` as the fallback.
- **Typed messages.** `MessageBody` is a sealed type (`TextBody`, `RecCardBody`). New message
  types add a class and a renderer.
- **Navigation.** `StatefulShellRoute.indexedStack` keeps each tab's history. Nested screens are
  registered under every tab, so deep links open inside the right tab.

## Demo vs production

| Demo (this build) | Production integration |
| --- | --- |
| Fictional client, holdings and quotes | MPC-owned Mosaic APIs and MPC-provided delayed market data |
| Explore Demo, no credentials | Real Mosaic authentication, tokens in Keychain / Keystore |
| Simulated approvals and audit log | Server-confirmed approvals recorded in Mosaic |
| Simulated adviser replies | Real adviser messaging over WebSocket |
| Simulated alerts from Settings | APNs / FCM, server-owned routing, K.ai event feed owned by MPC's technical lead |
| Sample audio and video | MPC Morning Call, Bulls vs. Bears and webinar media |
| Provisional legal copy | MPC-approved legal wording |

## Alert rules (server-side in production)

- Alert only clients who hold or watch the security and have that alert type enabled.
- De-duplicate by client, security, alert type, event and trading date.
- Price-move threshold is ±7% against the previous official close, on delayed data.
- The mobile client never monitors markets itself.

## Known limitations of this demo

- iOS and Android builds have **not** been built or run on devices yet. Only the web preview and
  `flutter test` have been run.
- Biometric unlock is simulated on web. Native builds need `local_auth` wiring.
- Firebase Messaging, `flutter_local_notifications`, `audio_service` and
  `flutter_secure_storage` are part of the production plan but are not added to this demo.
- Native protections are not verifiable in a browser: FLAG_SECURE, iOS capture detection,
  app-switcher blur, root and jailbreak checks, certificate pinning.
- The demo is not security-certified.
- BHP is in the seeded watchlist as the brief specifies. To show "Add to Watchlist" on BHP,
  remove it first, or use any security not on the list.
- Podcast audio is a SoundHelix sample track and the video is the Flutter sample clip. Both are
  labelled as demonstration media.

## Integration checklist

1. Receive Mosaic API docs, test accounts and auth flow from MPC's technical lead.
2. Map each `LiveMosaicRepository` method to its endpoint and response model.
3. Add `flutter_secure_storage` token store and refresh lifecycle.
4. Add `local_auth`, Firebase Messaging, APNs key and device token registration.
5. Add WebSocket chat transport and keep polling as fallback.
6. Replace sample media with MPC streams. Add `audio_service` for background playback.
7. Add certificate pinning, FLAG_SECURE, iOS capture protection and jailbreak warning.
8. Replace provisional legal copy with MPC-approved wording.

## Production release checklist

- Code in MPC's repository from day one, under MPC's IP assignment.
- Signing certificates and store listings under MPC's Apple and Google accounts.
- Test accounts only. No production client data in development or testing.
- Australian data residency for any backend or logging the app touches.
- TestFlight and Play internal testing, then store review.
- Accessibility pass with VoiceOver and TalkBack on real devices.

Copyright MPC Markets Pty Ltd. Demo prepared for MPC Markets.
