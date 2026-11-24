# Alertes nouveaux membres — Le Grand Partage

Les alertes sont déclenchées côté serveur à chaque nouvelle inscription dans `auth.users`. Elles ne dépendent donc pas du fait que le Super-Admin ait le site ouvert.

## 1. Déployer l'Edge Function

Déployer `supabase/functions/send-new-member-alert/index.ts` dans Supabase sous le nom `send-new-member-alert`.

Dans Supabase > Edge Functions > Secrets, définir :
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `NEW_MEMBER_ALERT_SECRET` : longue valeur aléatoire privée (au moins 32 caractères)
- `NEW_MEMBER_ALERT_EMAIL` : `Lp.cdjn@gmail.com`
- `RESEND_API_KEY` : clé API Resend
- `RESEND_FROM_EMAIL` : expéditeur vérifié chez Resend
- `VAPID_PUBLIC_KEY` et `VAPID_PRIVATE_KEY` : clés VAPID du projet
- `VAPID_SUBJECT` (facultatif)

## 2. Installer le déclencheur SQL

Ouvrir `supabase/new_member_alerts_trigger.sql` dans le dépôt. Remplacer `LE_SECRET_ALEATOIRE_ICI` par exactement la même valeur que `NEW_MEMBER_ALERT_SECRET`, puis exécuter tout le script dans Supabase > SQL Editor.

Ce déclencheur appelle l'Edge Function après chaque insertion dans `auth.users`.

## 3. Activer les notifications push sur le téléphone

Se connecter au site avec le compte Super-Admin, ouvrir Administration et appuyer sur « Activer les notifications sur cet appareil ». Autoriser les notifications Android/Chrome.

L'email part vers `Lp.cdjn@gmail.com`. L'alerte push est envoyée aux appareils sur lesquels le Super-Admin a activé les notifications. L'Edge Function vérifie les appels directs avec le rôle Super-Admin et les appels automatiques avec le secret privé partagé.
