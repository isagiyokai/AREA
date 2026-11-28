import { NextResponse } from "next/server";
import { verifyAndCreditPaystack } from "@/lib/payments/paystack-server";

export const runtime = "nodejs";

export async function GET(request: Request) {
  const url = new URL(request.url);
  const reference = url.searchParams.get("reference") || "";
  try {
    await verifyAndCreditPaystack(reference);
    return NextResponse.redirect(new URL("/wallet?payment=success", url.origin));
  } catch {
    return NextResponse.redirect(new URL("/wallet?payment=verify_failed", url.origin));
  }
}
