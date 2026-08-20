create extension if not exists pg_net;

create or replace function public.request_anomaly_analysis()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  trigger_secret text;
begin
  select decrypted_secret into trigger_secret
  from vault.decrypted_secrets
  where name = 'internal_trigger_secret';

  if trigger_secret is null then
    -- Secret not configured yet; skip silently rather than failing the insert.
    return new;
  end if;

  perform net.http_post(
    url := 'https://tnmznkdvrrpigevxdfet.supabase.co/functions/v1/generate-anomaly-analysis',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || trigger_secret
    ),
    body := jsonb_build_object('alert_id', new.id)
  );

  return new;
end;
$$;

drop trigger if exists alerts_ai_analysis on public.alerts;
create trigger alerts_ai_analysis
after insert on public.alerts
for each row execute function public.request_anomaly_analysis();
