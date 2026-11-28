import { createHmac, timingSafeEqual } from "node:crypto";
import { NextResponse } from "next/server";
import { markPaystackPaymentFailed, verifyAndCreditPaystack } from "@/lib/payments/paystack-server";

export const runtime = "nodejs";

export async function POST(request: Request) {
  const rawBody = await request.text();
  const currentSignature = request.headers.get("paystack-signature");
  const legacySignature = request.headers.get("x-paystack-signature");
  const signature = currentSignature || legacySignature;
  const signingSecret = currentSignature
    ? process.env.PAYSTACK_WEBHOOK_SECRET
    : process.env.PAYSTACK_SECRET_KEY;
  if (!signature || !signingSecret) {
    return NextResponse.json({ error: "Webhook signature is not configured." }, { status: 401 });
  }

  const expected = createHmac("sha512", signingSecret).update(rawBody).digest("hex");
  const suppliedBuffer = Buffer.from(signature, "hex");
  const expectedBuffer = Buffer.from(expected, "hex");
  if (suppliedBuffer.length !== expectedBuffer.length || !timingSafeEqual(suppliedBuffer, expectedBuffer)) {
    return NextResponse.json({ error: "Invalid webhook signature." }, { status: 401 });
  }

  let event: { event?: string; data?: { reference?: string } };
  try {
    event = JSON.parse(rawBody) as { event?: string; data?: { reference?: string } };
  } catch {
    return NextResponse.json({ error: "Invalid webhook payload." }, { status: 400 });
  }
  const reference = event.data?.reference;
  if (event.event === "charge.failed") {
    if (!reference) return NextResponse.json({ error: "Missing payment reference." }, { status: 400 });
    try {
      await markPaystackPaymentFailed(reference, "Paystack charge.failed event");
      return NextResponse.json({ received: true });
    } catch {
      return NextResponse.json({ error: "Could not mark failed payment." }, { status: 500 });
    }
  }
  if (event.event !== "charge.success") return NextResponse.json({ received: true });
  if (!reference) return NextResponse.json({ error: "Missing payment reference." }, { status: 400 });
  try {
    await verifyAndCreditPaystack(reference);
    return NextResponse.json({ received: true });
  } catch {
    return NextResponse.json({ error: "Payment verification or settlement failed." }, { status: 500 });
  }
}
