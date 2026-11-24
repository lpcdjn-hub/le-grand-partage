# Alertes nouveaux membres — Le Grand Partage

La surveillance est déclenchée depuis l'espace Super-Admin (interrogation de admin_list_users toutes les 45 secondes). À la première ouverture, la liste existante sert de référence : seules les inscriptions ultérieures déclenchent une alerte.

## Déploiement Supabase Edge Function

Déployer `supabase/functions/send-new-member-alert/index.ts` sous le nom `send-new-member-alert`.

Définir ces secrets dans Supabase > Edge Functions > Secrets :
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `RESEND_API_KEY` : clé API Resend
- `RESEND_FROM_EMAIL` : adresse expéditrice vérifiée chez Resend, par exemple un expéditeur sur votre domaine
- `NEW_MEMBER_ALERT_EMAIL` : `Lp.cdjn@gmail.com`
- `VAPID_PUBLIC_KEY` et `VAPID_PRIVATE_KEY` : les clés VAPID déjà utilisées par le site
- `VAPID_SUBJECT` (facultatif)

## Activation sur le téléphone du Super-Admin

Ouvrir le site avec le compte Super-Admin, ouvrir Administration, puis appuyer sur « Activer les notifications sur cet appareil » et autoriser les notifications. Faire cette étape sur chaque appareil où les notifications push sont souhaitées.

L'Edge Function vérifie le rôle Super-Admin avant d'envoyer les alertes. L'email est envoyé uniquement à l'adresse configurée ci-dessus.
