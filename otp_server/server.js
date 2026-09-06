import cors from 'cors';
import dotenv from 'dotenv';
import express from 'express';
import { Resend } from 'resend';
import Stripe from 'stripe';
import { fileURLToPath } from 'node:url';

dotenv.config({ path: fileURLToPath(new URL('.env', import.meta.url)) });

const app = express();
const port = Number(process.env.PORT || 3001);
const resend = process.env.RESEND_API_KEY
  ? new Resend(process.env.RESEND_API_KEY)
  : null;
const stripeKey = process.env.STRIPE_SECRET_KEY || '';
const stripe = stripeKey.startsWith('sk_test_') && !stripeKey.includes('replace')
  ? new Stripe(process.env.STRIPE_SECRET_KEY)
  : null;
const stripePaymentMethods = String(
  process.env.STRIPE_PAYMENT_METHODS || 'card,fpx',
)
  .split(',')
  .map((method) => method.trim())
  .filter(Boolean);

app.use(cors());
app.use(express.json({ limit: '128kb' }));

app.get('/health', (_request, response) => {
  response.json({
    ok: true,
    resendConfigured: Boolean(resend),
    stripeConfigured: Boolean(stripe),
  });
});

app.post('/send-otp', async (request, response) => {
  try {
    const email = normalizeEmail(request.body?.email);
    const otp = normalizeOtp(request.body?.otp);
    if (!email || !otp) {
      return response.status(400).json({
        ok: false,
        message: 'Email and 6-digit OTP are required.',
      });
    }
    if (!resend) {
      return response.status(503).json({
        ok: false,
        message: 'Email delivery is not configured. Please contact the app administrator.',
      });
    }

    const result = await resend.emails.send({
      from: process.env.RESEND_FROM || 'EcoAir Malaysia <onboarding@resend.dev>',
      to: email,
      subject: 'Your EcoAir password reset OTP',
      html: otpHtml(otp),
      text: `Your EcoAir password reset OTP is ${otp}. It expires in 10 minutes.`,
    });

    if (result?.error) {
      return response.status(502).json({
        ok: false,
        message: resendErrorMessage(result.error),
      });
    }

    if (!result?.data?.id) {
      return response.status(502).json({
        ok: false,
        message: 'The email provider did not confirm sending your OTP. Please try again.',
      });
    }
    response.json({ ok: true, id: result.data.id });
  } catch (error) {
    response.status(500).json({
      ok: false,
      message: resendErrorMessage(error),
    });
  }
});

app.post('/create-checkout-session', async (request, response) => {
  try {
    if (!stripe) {
      return response.status(503).json({
        ok: false,
        message:
          'Online banking test payments are not configured yet. Please contact the app administrator.',
      });
    }

    const items = normalizeLineItems(request.body?.items);
    if (!items.length) {
      return response.status(400).json({
        ok: false,
        message: 'At least one checkout item is required.',
      });
    }

    const session = await stripe.checkout.sessions.create({
      mode: 'payment',
      payment_method_types: stripePaymentMethods.length
        ? stripePaymentMethods
        : ['card'],
      line_items: items,
      success_url:
        process.env.STRIPE_SUCCESS_URL ||
        'http://10.0.2.2:3001/payment-success',
      cancel_url:
        process.env.STRIPE_CANCEL_URL ||
        'http://10.0.2.2:3001/payment-cancelled',
      metadata: {
        app: 'EcoAir Malaysia',
        customerName: String(request.body?.customerName || '').slice(0, 80),
      },
    });

    response.json({ ok: true, url: session.url });
  } catch (error) {
    response.status(500).json({
      ok: false,
      message: stripeErrorMessage(error),
    });
  }
});

app.get('/payment-success', (_request, response) => {
  response.type('html').send(paymentPage('Payment demo completed'));
});

app.get('/payment-cancelled', (_request, response) => {
  response.type('html').send(paymentPage('Payment demo cancelled'));
});

app.listen(port, '0.0.0.0', () => {
  console.log(`EcoAir OTP server running on http://localhost:${port}`);
});

function normalizeEmail(value) {
  const email = String(value || '').trim().toLowerCase();
  return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) ? email : '';
}

function normalizeOtp(value) {
  const otp = String(value || '').replace(/\s+/g, '').trim();
  return /^\d{6}$/.test(otp) ? otp : '';
}

function normalizeLineItems(value) {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => {
      const name = String(item?.name || 'EcoAir product').slice(0, 120);
      const quantity = Math.max(1, Math.min(99, Number(item?.quantity) || 1));
      const amount = Math.round((Number(item?.unitPrice) || 0) * 100);
      if (amount <= 0) return null;
      return {
        price_data: {
          currency: process.env.STRIPE_CURRENCY || 'myr',
          product_data: { name },
          unit_amount: amount,
        },
        quantity,
      };
    })
    .filter(Boolean);
}

function resendErrorMessage(error) {
  const message = String(error?.message || error?.name || error).toLowerCase();
  if (message.includes('testing emails') || message.includes('own email')) {
    return 'This email service can currently send only to the Resend account owner. Sending to other addresses requires a verified sender domain.';
  }
  if (message.includes('domain')) {
    return 'The sender domain is not verified. Please contact the app administrator to enable email delivery.';
  }
  if (message.includes('api key') || message.includes('unauthorized')) {
    return 'The email service could not authenticate. Please contact the app administrator.';
  }
  if (message.includes('rate') || message.includes('quota')) {
    return 'The email service has reached its sending limit. Please try again later.';
  }
  return 'Your OTP email could not be sent. Please try again shortly.';
}

function stripeErrorMessage(error) {
  return error?.message || 'Stripe checkout could not be created.';
}

function otpHtml(otp) {
  return `
    <div style="font-family:Arial,sans-serif;line-height:1.5;color:#0f172a">
      <h2 style="color:#059669">EcoAir Malaysia</h2>
      <p>Your password reset OTP is:</p>
      <p style="font-size:32px;font-weight:700;letter-spacing:6px">${otp}</p>
      <p>This code expires in 10 minutes. If you did not request this, ignore this email.</p>
    </div>
  `;
}

function paymentPage(title) {
  return `
    <!doctype html>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>${title}</title>
    <body style="font-family:Arial,sans-serif;background:#f6f8fb;margin:0;padding:32px;color:#0f172a">
      <main style="max-width:520px;margin:48px auto;background:white;border-radius:20px;padding:28px;box-shadow:0 12px 36px rgba(15,23,42,.08)">
        <h1 style="color:#059669;margin-top:0">${title}</h1>
        <p>You can return to EcoAir Malaysia and confirm the order record in the app.</p>
      </main>
    </body>
  `;
}
