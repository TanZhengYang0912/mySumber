-- Customer review flow has been removed from the app. Clear its legacy rows.
do $$
begin
  if to_regclass('public.service_reviews') is not null then
    delete from public.service_reviews;
  end if;

  if to_regclass('public.ai_summaries') is not null then
    delete from public.ai_summaries;
  end if;
end
$$;
