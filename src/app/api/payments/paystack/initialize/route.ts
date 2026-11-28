import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";

export const runtime = "nodejs";

export async function POST(request: Request) {
  try {
    const secret = process.env.PAYSTACK_SECRET_KEY;
    const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
    if (!secret || !serviceRoleKey) {
      return NextResponse.json({ error: "AREA checkout is not configured yet. No payment has been taken." }, { status: 503 });
    }
    const supabase = await createClient();
    if (!supabase) return NextResponse.json({ error: "Authentication is unavailable." }, { status: 503 });
    const { data: { user } } = await supabase.auth.getUser();
    if (!user?.email) return NextResponse.json({ error: "Sign in with an email address before paying." }, { status: 401 });

    const body = (await request.json()) as { package_key?: string; order_type?: "topup" | "entry"; tier_key?: string };
    const orderType = body.order_type || "topup";
    let order: unknown;
    if (orderType === "entry") {
      if (!body.tier_key) return NextResponse.json({ error: "Choose an entry tier." }, { status: 400 });
      const { data, error } = await supabase.rpc("create_area_entry_order", { p_tier_key: body.tier_key });
      if (error) throw error;
      order = data;
    } else {
      if (!body.package_key) return NextResponse.json({ error: "Choose an AC package." }, { status: 400 });
      const { data, error } = await supabase.rpc("create_ac_topup_order", { p_package_key: body.package_key });
      if (error) throw error;
      order = data;
    }
    const checkout = order as { reference: string; amount_ngn: number; total_ac: number; order_type?: string; tier_key?: string };
    const origin = process.env.NEXT_PUBLIC_SITE_URL || new URL(request.url).origin;
    const response = await fetch("https://api.paystack.co/transaction/initialize", {
      method: "POST",
      headers: { Authorization: `Bearer ${secret}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        email: user.email,
        amount: checkout.amount_ngn * 100,
        currency: "NGN",
        reference: checkout.reference,
        callback_url: `${origin}/api/payments/paystack/callback`,
        metadata: { area_reference: checkout.reference, product: checkout.order_type === "entry" ? "AREA entry tier" : "AREA AC" },
      }),
      cache: "no-store",
    });
    const result = (await response.json()) as { status: boolean; message?: string; data?: { authorization_url: string; reference: string } };
    if (!response.ok || !result.status || !result.data?.authorization_url || result.data.reference !== checkout.reference) {
      throw new Error(result.message || "Could not start Paystack checkout.");
    }
    return NextResponse.json({ authorization_url: result.data.authorization_url });
  } catch (error) {
    return NextResponse.json({ error: error instanceof Error ? error.message : "Could not start checkout." }, { status: 400 });
  }
}
