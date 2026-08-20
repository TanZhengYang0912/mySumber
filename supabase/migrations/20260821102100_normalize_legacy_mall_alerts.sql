-- Alerts created by the retired status trigger arrived directly in the worker
-- queue and had no source key. Normalize only those legacy, still-open Mall
-- rows that correspond to the current demo anomalies.
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
update public.alerts as alert
set
  state = coalesce(target.zone_id, 'Malaysia'),
  detected_at = target.timestamp,
  signature = case when target.is_water then 'NRW hotspot' else 'Electricity loss hotspot' end,
  severity = case when target.is_critical then 'high' else 'medium' end,
  explanation = target.node_name || ' at ' ||
    coalesce(target.facility_name, 'an unlinked facility') ||
    ' recorded ' || target.multiple || 'x its normal usage (' ||
    round(target.usage_value::numeric, 1) || ' against a ' ||
    round(target.baseline::numeric, 1) || ' baseline from its last seven readings). ' ||
    'Equipment drawing this far above baseline risks unmetered loss until serviced. ' ||
    'Recommend an on-site inspection of the unit.',
  status = 'pending_review',
  source_scope = 'mall',
  utility_type = case when target.is_water then 'water' else 'electricity' end,
  source_key = 'mall:' || target.node_id::text || ':' ||
    to_char(target.timestamp, 'YYYY-MM-DD"T"HH24:MI:SS'),
  ai_summary = target.node_name || ' at ' ||
    coalesce(target.facility_name, 'an unlinked facility') ||
    ' is drawing ' || target.multiple || 'x its seven-reading baseline, a ' ||
    case when target.is_water then 'water' else 'electricity' end ||
    ' consumption level consistent with ' ||
    case when target.is_critical then 'an active fault' else 'developing wear' end || '.',
  ai_possible_cause = case
    when target.is_water and target.is_critical then
      'A failed seal, a stuck-open valve, or a burst section downstream of the meter.'
    when target.is_water then
      'Early seal wear, a partially seized valve, or a slow downstream leak.'
    when target.is_critical then
      'A shorted winding, a failing capacitor bank, or load that has been transferred onto this unit.'
    else
      'Degrading insulation, dirty contacts, or a gradual load increase on this circuit.'
  end,
  ai_severity_assessment = case when target.is_critical then
    'High. At ' || target.multiple || 'x baseline the unit is past the 1.50x threshold and losing measurable volume every hour it stays in service.'
  else
    'Medium. At ' || target.multiple || 'x baseline the unit is above the 1.25x warning threshold but below the 1.50x critical line, so there is time to schedule rather than scramble.'
  end,
  ai_recommendation = case when target.is_critical then
    'Dispatch a technician to ' || coalesce(target.facility_name, 'the site') ||
    ' today. Isolate the unit if the reading holds, and compare the meter against the ' ||
    round(target.baseline::numeric, 1) || ' baseline before restoring it to service.'
  else
    'Add ' || coalesce(target.facility_name, 'the site') ||
    ' to the next maintenance round. Log two more readings first — if the trend holds above ' ||
    round((target.baseline * 1.25)::numeric, 1) || ', escalate to an on-site inspection.'
  end,
  ai_confidence = case when target.is_critical then 0.88 else 0.79 end,
  ai_generated_at = now()
from target
where alert.equipment_node_id = target.node_id::text
  and alert.is_deleted = false
  and alert.source_scope = 'mall'
  and alert.source_key is null
  and alert.status = 'pending';
