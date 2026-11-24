import { createClient } from "npm:@supabase/supabase-js@2";
import webpush from "npm:web-push";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabaseAdmin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

const cors = {
  "Access-Control-Allow-Origin": "https://lpcdjn-hub.github.io",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return Response.json({ error: "Method not allowed" }, { status: 405, headers: cors });

  try {
    const internalSecret = req.headers.get("x-alert-secret") || "";
    const expectedSecret = Deno.env.get("NEW_MEMBER_ALERT_SECRET") || "";
    const isInternal = Boolean(expectedSecret && internalSecret && internalSecret === expectedSecret);
    let alertAdminUserId = "";

    if (!isInternal) {
      const token = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
      if (!token) return Response.json({ error: "Unauthorized" }, { status: 401, headers: cors });
      const userClient = createClient(SUPABASE_URL, ANON_KEY, { global: { headers: { Authorization: "Bearer " + token } } });
      const { data: authData, error: authError } = await userClient.auth.getUser();
      if (authError || !authData.user) return Response.json({ error: "Unauthorized" }, { status: 401, headers: cors });
      const { data: isAdmin, error: adminError } = await userClient.rpc("is_admin");
      if (adminError || isAdmin !== true) return Response.json({ error: "Forbidden" }, { status: 403, headers: cors });
      alertAdminUserId = authData.user.id;
    }

    const body = await req.json();
    const userId = String(body?.user_id || "");
    if (!userId) return Response.json({ error: "user_id required" }, { status: 400, headers: cors });
    if (isInternal) {
      const { data: admins, error: adminsError } = await supabaseAdmin.auth.admin.listUsers({ page: 1, perPage: 1000 });
      if (adminsError) throw adminsError;
      const adminUser = (admins.users || []).find(u => (u.email || "").toLowerCase() === "lp.cdjn@gmail.com");
      if (!adminUser) throw new Error("Compte Super-Admin introuvable pour les notifications push.");
      alertAdminUserId = adminUser.id;
    }

    const { data: memberData, error: memberError } = await supabaseAdmin.auth.admin.getUserById(userId);
    if (memberError || !memberData.user) return Response.json({ error: "Member not found" }, { status: 404, headers: cors });
    const member = memberData.user;
    const displayName = String(member.user_metadata?.display_name || "Nouveau membre").slice(0, 80);
    const createdAt = member.created_at || new Date().toISOString();

    let emailSent = false;
    let emailError: string | null = null;
    const resendKey = Deno.env.get("RESEND_API_KEY");
    const from = Deno.env.get("RESEND_FROM_EMAIL");
    const to = Deno.env.get("NEW_MEMBER_ALERT_EMAIL") || "Lp.cdjn@gmail.com";
    if (resendKey && from) {
      const mail = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: { "Authorization": "Bearer " + resendKey, "Content-Type": "application/json" },
        body: JSON.stringify({
          from,
          to: [to],
          subject: "Le Grand Partage — Nouvelle inscription",
          html: "<h2>Un nouveau membre vient de rejoindre Le Grand Partage</h2><p><strong>Pseudo :</strong> " + displayName.replace(/[&<>"]/g, "") + "</p><p><strong>Date :</strong> " + new Date(createdAt).toLocaleString("fr-FR", { timeZone: "Europe/Paris" }) + "</p><p>Connectez-vous à votre espace Super-Admin pour consulter la liste des membres.</p><p><a href=\"https://lpcdjn-hub.github.io/le-grand-partage/\">Ouvrir Le Grand Partage</a></p>"
        })
      });
      emailSent = mail.ok;
      if (!mail.ok) emailError = (await mail.text()).slice(0, 500);
    } else {
      emailError = "Configuration manquante : RESEND_API_KEY et RESEND_FROM_EMAIL doivent être définis dans les secrets de la fonction.";
    }

    let pushSent = 0;
    let pushError: string | null = null;
    const vapidPublic = Deno.env.get("VAPID_PUBLIC_KEY");
    const vapidPrivate = Deno.env.get("VAPID_PRIVATE_KEY");
    if (vapidPublic && vapidPrivate) {
      webpush.setVapidDetails(Deno.env.get("VAPID_SUBJECT") || "mailto:" + to, vapidPublic, vapidPrivate);
      const { data: subscriptions, error: subError } = await supabaseAdmin.from("push_subscriptions").select("endpoint,subscription").eq("user_id", alertAdminUserId);
      if (subError) pushError = subError.message;
      else {
        for (const row of subscriptions || []) {
          try {
            await webpush.sendNotification(row.subscription, JSON.stringify({
              title: "Le Grand Partage — Nouveau membre",
              body: displayName + " vient de rejoindre la communauté.",
              url: "/le-grand-partage/",
              tag: "new-member-" + userId
            }));
            pushSent++;
          } catch (e) {
            if (e?.statusCode === 404 || e?.statusCode === 410) await supabaseAdmin.from("push_subscriptions").delete().eq("endpoint", row.endpoint);
            pushError = String(e?.message || e);
          }
        }
      }
    } else {
      pushError = "Clés VAPID manquantes dans les secrets de la fonction.";
    }

    return Response.json({ ok: true, email_sent: emailSent, email_error: emailError, push_sent: pushSent, push_error: pushError }, { headers: cors });
  } catch (e) {
    return Response.json({ error: String(e?.message || e) }, { status: 500, headers: cors });
  }
});
