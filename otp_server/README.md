# EcoAir OTP and Payment Demo Server

This small local backend is used by the Flutter app for:

- Sending password reset OTP emails with Resend.
- Creating Stripe Checkout test payment sessions.

## Setup

Install dependencies once:

```powershell
cd F:\StudioProjects1\ecoair\otp_server
npm install
```

Create or edit `.env`:

```env
PORT=3001
RESEND_API_KEY=replace_with_resend_key
RESEND_FROM="EcoAir Malaysia <onboarding@resend.dev>"
STRIPE_SECRET_KEY=sk_test_replace_with_stripe_key
STRIPE_CURRENCY=myr
STRIPE_PAYMENT_METHODS=card,fpx
STRIPE_SUCCESS_URL=http://10.0.2.2:3001/payment-success
STRIPE_CANCEL_URL=http://10.0.2.2:3001/payment-cancelled
```

For a class demo, `onboarding@resend.dev` is the easiest Resend sender. To use a branded sender, verify your own domain in Resend first. Gmail addresses cannot be used directly as the sender domain.

The Resend testing sender can send only to your Resend account email. Other recipients require a verified domain. The app no longer displays or returns OTP codes; a delivery failure shows an error and invalidates the failed code.

Stripe must use an `sk_test_...` secret key. Live keys are not enabled in this coursework backend. Enable FPX in the matching test environment and keep the currency as MYR. The hosted Checkout integration does not need a publishable key in Flutter. At present, saving a local order is a separate confirmation, not server verification of payment.

## Run

Start the backend:

On Windows, run `otp_server/start-server.ps1` to start it in the background. Logs stay in `otp_server/.logs` on F:.

After changing `.env`, run `./otp_server/start-server.ps1 -Restart` from the project directory. The server loads keys at startup, so editing the file alone does not update the running process.

```powershell
cd F:\StudioProjects1\ecoair\otp_server
npm run dev
```

Run Flutter for the Android emulator with:

```powershell
F:\flutter\bin\flutter.bat run --dart-define=ECOAIR_BACKEND_URL=http://10.0.2.2:3001
```

In Android Studio, add this to **Run > Edit Configurations > Additional run args**:

```text
--dart-define=ECOAIR_BACKEND_URL=http://10.0.2.2:3001
```

Use `http://localhost:3001` only for desktop or web runs. Android emulator uses `http://10.0.2.2:3001` to reach the computer host.

The project's `main.dart` run configuration includes this address, and debug builds default to it. After changing a dart-define or installing this update, fully stop and run the app again. Hot reload cannot change compile-time configuration. Release builds need an explicit backend URL. Physical phones need the computer's LAN address, not 10.0.2.2.
