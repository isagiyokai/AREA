import { createClient as createSupabaseClient } from "@supabase/supabase-js";

type PaystackVerifyResponse = {
  status: boolean;
  message?: string;
  data?: {
    id: number | string;
    status: string;
    reference: string;
    amount: number;
    currency: string;
    paid_at?: string | null;
    channel?: string | null;
    fees?: number | null;
    gateway_response?: string | null;
  };
};

export async function verifyAndCreditPaystack(reference: string) {
  const secret = process.env.PAYSTACK_SECRET_KEY;
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!secret || !supabaseUrl || !serviceRoleKey) {
    throw new Error("Payment settlement is not configured on the server.");
  }
  if (!/^area_[a-f0-9]{32}$/.test(reference)) {
    throw new Error("Invalid AREA payment reference.");
  }

  const response = await fetch(
    `https://api.paystack.co/transaction/verify/${encodeURIComponent(reference)}`,
    { headers: { Authorization: `Bearer ${secret}` }, cache: "no-store" },
  );
  const verified = (await response.json()) as PaystackVerifyResponse;
  const payment = verified.data;
  if (!response.ok || !verified.status || !payment) {
    throw new Error(verified.message || "Paystack could not verify this payment.");
  }
  if (payment.reference !== reference) {
    throw new Error("Paystack returned a different payment reference.");
  }
  if (payment.status === "failed" || payment.status === "abandoned") {
    await markPaystackPaymentFailed(reference, payment.status);
    throw new Error("The payment did not complete. You can try again.");
  }
  if (
    payment.status !== "success" ||
    payment.currency !== "NGN" ||
    !Number.isSafeInteger(payment.amount) ||
    payment.amount <= 0
  ) {
    throw new Error("Payment is not successful or does not match the AREA order.");
  }

  const admin = createSupabaseClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data, error } = await admin.rpc("settle_verified_ac_payment", {
    p_reference: reference,
    p_provider_transaction_id: String(payment.id),
    p_amount_kobo: payment.amount,
    p_currency: payment.currency,
    p_paid_at: payment.paid_at || null,
    p_provider_payload: {
      channel: payment.channel || null,
      fees_kobo: payment.fees ?? null,
      gateway_response: payment.gateway_response || null,
    },
  });
  if (error) throw new Error(error.message);
  return data as {
    credited: boolean;
    already_paid: boolean;
    base_ac?: number;
    bonus_ac?: number;
    total_ac: number;
    balance_ac?: number;
  };
}

export async function markPaystackPaymentFailed(reference: string, reason: string) {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!supabaseUrl || !serviceRoleKey) throw new Error("Payment settlement is not configured.");
  const admin = createSupabaseClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { error } = await admin.rpc("fail_ac_payment_order", {
    p_reference: reference,
    p_reason: reason.slice(0, 160),
  });
  if (error) throw new Error(error.message);
}
