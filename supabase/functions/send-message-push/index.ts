import { createClient } from "npm:@supabase/supabase-js@2";
import webpush from "npm:web-push";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

webpush.setVapidDetails(
  Deno.env.get("VAPID_SUBJECT") || "mailto:contact@legrandpartage.fr",
  Deno.env.get("VAPID_PUBLIC_KEY")!,
  Deno.env.get("VAPID_PRIVATE_KEY")!
);

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  const token = (req.headers.get("Authorization") || "").replace(/^Bearer\\s+/i, "");
  if (!token) return new Response("Unauthorized", { status: 401 });

  try {
    const { data: authData, error: authError } = await supabase.auth.getUser(token);
    const user = authData?.user;
    if (authError || !user) return new Response("Unauthorized", { status: 401 });

    const { message_id } = await req.json();
    if (!message_id) return new Response("message_id required", { status: 400 });

    const { data: message, error } = await supabase
      .from("messages")
      .select("id,body,recipient_id,sender_id,listing_id")
      .eq("id", message_id)
      .single();

    if (error || !message) return new Response("Message not found", { status: 404 });
    if (message.sender_id !== user.id) return new Response("Forbidden", { status: 403 });

    const { data: subs, error: subsError } = await supabase
      .from("push_subscriptions")
      .select("subscription")
      .eq("user_id", message.recipient_id);
    if (subsError) throw subsError;

    const payload = JSON.stringify({
      title: "Le Grand Partage — Nouveau message",
      body: String(message.body || "Vous avez reçu un message").slice(0, 160),
      url: "/le-grand-partage/?messages=1",
      tag: "message-" + message.id
    });

    const results = await Promise.all((subs || []).map(async row => {
      try {
        await webpush.sendNotification(row.subscription, payload);
        return true;
      } catch (e) {
        if (e?.statusCode === 404 || e?.statusCode === 410) {
          await supabase.from("push_subscriptions").delete().eq("endpoint", row.subscription.endpoint);
        }
        return false;
      }
    }));
    return Response.json({ sent: results.filter(Boolean).length });
  } catch (e) {
    return new Response(String(e?.message || e), { status: 500 });
  }
});
