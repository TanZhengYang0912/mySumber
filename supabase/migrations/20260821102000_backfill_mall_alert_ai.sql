-- Static demo alerts are inserted with audited, templated AI content so this
-- migration never queues a Groq request. Live alerts still insert AI columns
-- as NULL and go through the alerts_ai_analysis trigger.
with latest as (
  select distinct on (log.node_id)
    log.node_id, log.usage_value, log.timestamp
  from public.equipment_usage_logs as log
  order by log.node_id, log.timestamp desc
),
scored as (
  select
    latest.node_id,
    latest.usage_value,
    latest.timestamp,
    (select avg(prior.usage_value) from (
       select usage_value
       from public.equipment_usage_logs as b
       where b.node_id = latest.node_id
         and b.timestamp < latest.timestamp
         and b.is_anomaly = false
       order by b.timestamp desc
       limit 7
     ) as prior) as baseline
  from latest
),
target as (
  select
    node.node_id, node.node_name, node.utility_type, node.status,
    node.zone_id, node.facility_name, node.facility_city,
    scored.usage_value, scored.baseline, scored.timestamp,
    round((scored.usage_value / scored.baseline)::numeric, 2) as multiple,
    node.utility_type = 'Water' as is_water,
    node.status = 'Critical' as is_critical
  from scored
  join public.equipment_nodes as node using (node_id)
  where scored.baseline is not null
    and scored.baseline > 0
    and node.status in ('Warning', 'Critical')
)
insert into public.alerts (
  alert_type, state, detected_at, signature, severity, explanation, status,
  is_deleted, equipment_node_id, facility_name, facility_city, equipment_name,
  data_year, source_scope, utility_type, source_key,
  ai_summary, ai_possible_cause, ai_severity_assessment,
  ai_recommendation, ai_confidence, ai_generated_at
)
select
  case when is_water then 'nrw_hotspot' else 'electricity_hotspot' end,
  coalesce(zone_id, 'Malaysia'),
  now(),
  case when is_water then 'NRW hotspot' else 'Electricity loss hotspot' end,
  case when is_critical then 'high' else 'medium' end,
  node_name || ' at ' || coalesce(facility_name, 'an unlinked facility') ||
    ' recorded ' || multiple || 'x its normal usage (' ||
    round(usage_value::numeric, 1) || ' against a ' ||
    round(baseline::numeric, 1) || ' baseline from its last seven readings). ' ||
    'Equipment drawing this far above baseline risks unmetered loss until ' ||
    'serviced. Recommend an on-site inspection of the unit.',
  'pending_review', false, node_id::text, facility_name, facility_city,
  node_name, extract(year from timestamp)::int,
  'mall',
  case when is_water then 'water' else 'electricity' end,
  'mall:' || node_id::text || ':' ||
    to_char(timestamp, 'YYYY-MM-DD"T"HH24:MI:SS'),
  node_name || ' at ' || coalesce(facility_name, 'an unlinked facility') ||
    ' is drawing ' || multiple || 'x its seven-reading baseline, a ' ||
    case when is_water then 'water' else 'electricity' end ||
    ' consumption level consistent with ' ||
    case when is_critical then 'an active fault' else 'developing wear' end || '.',
  case
    when is_water and is_critical then
      'A failed seal, a stuck-open valve, or a burst section downstream of the meter.'
    when is_water then
      'Early seal wear, a partially seized valve, or a slow downstream leak.'
    when is_critical then
      'A shorted winding, a failing capacitor bank, or load that has been transferred onto this unit.'
    else
      'Degrading insulation, dirty contacts, or a gradual load increase on this circuit.'
  end,
  case when is_critical then
    'High. At ' || multiple || 'x baseline the unit is past the 1.50x threshold and losing measurable volume every hour it stays in service.'
  else
    'Medium. At ' || multiple || 'x baseline the unit is above the 1.25x warning threshold but below the 1.50x critical line, so there is time to schedule rather than scramble.'
  end,
  case when is_critical then
    'Dispatch a technician to ' || coalesce(facility_name, 'the site') ||
    ' today. Isolate the unit if the reading holds, and compare the meter against the ' ||
    round(baseline::numeric, 1) || ' baseline before restoring it to service.'
  else
    'Add ' || coalesce(facility_name, 'the site') ||
    ' to the next maintenance round. Log two more readings first — if the trend holds above ' ||
    round((baseline * 1.25)::numeric, 1) || ', escalate to an on-site inspection.'
  end,
  case when is_critical then 0.88 else 0.79 end,
  now()
from target
where not exists (
  select 1 from public.alerts as existing
  where existing.equipment_node_id = target.node_id::text
    and existing.is_deleted = false
    and existing.status in ('pending_review', 'pending', 'investigating', 'not_fixed')
);
