// Supabase Edge Function: send_qr_email
// Deno runtime

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type PaymentRow = {
  id: string;
  family_admin_id: string | null;
  email: string | null;
  qr_url: string | null;
  status: string | null;
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;

function corsHeaders() {
  return {
    "access-control-allow-origin": "*",
    "access-control-allow-headers": "*",
    "access-control-allow-methods": "POST, OPTIONS",
    "content-type": "application/json",
  } as const;
}

async function sendEmail(to: string, qrUrl: string) {
  const html = `
    <div style="font-family: system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial, sans-serif; line-height:1.6;">
      <h2>Your UPI Payment QR Code</h2>
      <p>Thank you for supporting Apna Parivaar. Please scan the QR code below to pay ₹500.</p>
      <img src="${qrUrl}" alt="UPI QR Code" style="max-width:320px; width:100%; border:1px solid #ddd; border-radius:8px;"/>
      <p>If the image does not load, <a href="${qrUrl}">click here</a>.</p>
    </div>
  `;

  const body = {
    from: "Apna Parivaar <no-reply@apna-parivaar.local>",
    to: [to],
    subject: "Your UPI Payment QR Code",
    html,
  };

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Resend error: ${res.status} ${text}`);
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders() });
  }

  try {
    const { paymentId } = await req.json();
    if (!paymentId) {
      return new Response(JSON.stringify({ error: "paymentId required" }), {
        status: 400,
        headers: corsHeaders(),
      });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE);

    const { data: payment, error } = await supabase
      .from("payments")
      .select("id, family_admin_id, email, qr_url, status")
      .eq("id", paymentId)
      .single<PaymentRow>();
    if (error || !payment) {
      throw new Error(`Payment not found: ${error?.message ?? "unknown"}`);
    }
    if (!payment.email || !payment.qr_url) {
      throw new Error("Payment row missing email or qr_url");
    }

    let newStatus = "email_sent";
    try {
      if (!RESEND_API_KEY) throw new Error("RESEND_API_KEY missing");
      await sendEmail(payment.email, payment.qr_url);
      newStatus = "email_sent";
    } catch (emailErr) {
      // Fallback when Resend is not configured/working
      newStatus = "email_skipped";
    }

    const { error: updateErr } = await supabase
      .from("payments")
      .update({ status: newStatus })
      .eq("id", payment.id);
    if (updateErr) throw updateErr;

    return new Response(JSON.stringify({ success: true }), {
      headers: corsHeaders(),
      status: 200,
    });
  } catch (e) {
    return new Response(
      JSON.stringify({ success: false, error: (e as Error).message }),
      { headers: corsHeaders(), status: 500 }
    );
  }
});


