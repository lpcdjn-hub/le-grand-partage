-- Le Grand Partage — déclenchement automatique des alertes à chaque inscription
-- À exécuter dans Supabase > SQL Editor après avoir créé le secret Vault indiqué ci-dessous.
-- Le secret doit être identique au secret NEW_MEMBER_ALERT_SECRET de l'Edge Function.
-- Remplacez LE_SECRET_ALEATOIRE_ICI par une longue valeur aléatoire privée.

create extension if not exists pg_net with schema extensions;
create extension if not exists supabase_vault with schema vault;

select vault.create_secret(
  'LE_SECRET_ALEATOIRE_ICI',
  'lgp_new_member_alert_secret',
  'Secret partagé entre le déclencheur SQL et l’Edge Function des nouveaux membres'
);

create or replace function public.notify_new_member_signup()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  alert_secret text;
begin
  select decrypted_secret into alert_secret
  from vault.decrypted_secrets
  where name = 'lgp_new_member_alert_secret'
  limit 1;

  if alert_secret is null or length(alert_secret) < 32 then
    raise warning 'Le secret Vault des alertes nouveaux membres est absent ou trop court.';
    return new;
  end if;

  perform net.http_post(
    url := 'https://lioydkmparojxbsaydzo.supabase.co/functions/v1/send-new-member-alert',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-alert-secret', alert_secret
    ),
    body := jsonb_build_object('user_id', new.id::text)
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_notify_admin on auth.users;
create trigger on_auth_user_created_notify_admin
after insert on auth.users
for each row execute procedure public.notify_new_member_signup();
