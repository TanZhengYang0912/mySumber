"""Generate the seed INSERT for state-scope alerts.

Replicates, exactly:
  - NrwService.analyse()              (water, thresholds 50/40, skip <= national)
  - ElectricityLossService.analyse()  (electricity, thresholds 40/25, skip <= national)
  - ElectricityDataService + AnomalyDetector.isAnomaly (tampering, |z| > 2.5)
  - Explainer.describeNrw / describeElectricityLoss / describeTampering
  - AppState.monthKey  ->  '<year>-<month>' (unpadded)

Run from the repo root. Writes SQL to stdout.
"""
import csv
import collections
import math


def accumulate(path, state_i, date_i, value_i, sector_i=None, sector_value=None):
    out = collections.defaultdict(lambda: collections.defaultdict(float))
    with open(path) as handle:
        rows = csv.reader(handle)
        next(rows)
        for row in rows:
            if len(row) <= max(state_i, date_i, value_i):
                continue
            if sector_i is not None and row[sector_i].strip() != sector_value:
                continue
            out[row[state_i].strip()][int(row[date_i].strip()[:4])] += float(row[value_i])
    return out


def latest_shared_year(left, right, state):
    if state not in left or state not in right:
        return None
    shared = [y for y in left[state] if y in right[state]]
    return max(shared) if shared else None


def sql_quote(text):
    return text.replace("'", "''")


rows = []

# --- Water: NrwService ---
produced = accumulate('assets/water_production.csv', 0, 1, 2)
billed = accumulate('assets/water_consumption.csv', 0, 2, 3)
year = latest_shared_year(produced, billed, 'Malaysia')
national_water = (produced['Malaysia'][year] - billed['Malaysia'][year]) / produced['Malaysia'][year] * 100

for state in produced:
    if state == 'Malaysia':
        continue
    y = latest_shared_year(produced, billed, state)
    if y is None:
        continue
    p, b = produced[state][y], billed[state][y]
    if p == 0:
        continue
    loss = p - b
    pct = loss / p * 100
    if pct <= national_water:
        continue
    severity = 'high' if pct > 50 else 'medium' if pct > 40 else 'low'
    explanation = (
        f"{state} loses {pct:.1f}% of treated water in {y}, above the national "
        f"average of {national_water:.1f}%. A loss this high points to "
        f"distribution-network leakage rather than metering error. Recommend a "
        f"field inspection of the district network."
    )
    rows.append(('nrw_hotspot', state, 'NRW hotspot', severity, explanation,
                 p, b, loss, pct, y, 'water', f'state:water:{state}:{y}'))

# --- Electricity: ElectricityLossService ---
supply = accumulate('assets/electricity_supply.csv', 0, 1, 3, 2, 'total')
consumption = accumulate('assets/electricity_consumption.csv', 0, 1, 3, 2, 'total')
total_supply = total_consumption = 0.0
for state in supply:
    y = latest_shared_year(supply, consumption, state)
    if y is None:
        continue
    total_supply += supply[state][y]
    total_consumption += consumption[state][y]
national_elec = (total_supply - total_consumption) / total_supply * 100

for state in supply:
    y = latest_shared_year(supply, consumption, state)
    if y is None:
        continue
    s, c = supply[state][y], consumption[state][y]
    if s <= 0:
        continue
    loss = s - c
    pct = loss / s * 100
    if pct <= national_elec:
        continue
    severity = 'high' if pct > 40 else 'medium' if pct > 25 else 'low'
    explanation = (
        f"{state} shows {pct:.1f}% of supplied electricity unaccounted for in "
        f"{y}, above the national average of {national_elec:.1f}%. A gap this "
        f"large between supply and metered consumption points to distribution "
        f"losses or meter tampering. Recommend a field audit of the "
        f"distribution grid."
    )
    rows.append(('electricity_hotspot', state, 'Electricity loss hotspot', severity,
                 explanation, s, c, loss, pct, y, 'electricity',
                 f'state:electricity:{state}:{y}'))

# --- Tampering: ElectricityDataService, national monthly losses, |z| > 2.5 ---
month_supply = collections.defaultdict(float)
month_total = collections.defaultdict(float)
month_losses = collections.defaultdict(float)
with open('assets/electricity_supply.csv') as handle:
    reader = csv.reader(handle)
    next(reader)
    for row in reader:
        if len(row) >= 4:
            month_supply[row[1]] += float(row[3])
with open('assets/electricity_consumption.csv') as handle:
    reader = csv.reader(handle)
    next(reader)
    for row in reader:
        if len(row) < 4:
            continue
        sector = row[2].lower()
        if sector == 'total':
            month_total[row[1]] += float(row[3])
        elif sector == 'losses':
            month_losses[row[1]] += float(row[3])

history = []
for date_str in sorted(month_total):
    losses = month_losses.get(date_str, 0.0)
    z = 0.0
    if len(history) >= 2:
        mean = sum(history) / len(history)
        variance = sum((v - mean) ** 2 for v in history) / (len(history) - 1)
        std = math.sqrt(variance)
        z = 0.0 if std == 0 else (losses - mean) / std
    if abs(z) > 2.5:
        s = month_supply.get(date_str, 0.0)
        c = month_total[date_str]
        pct = 0.0 if s == 0 else losses / s * 100
        y, m = int(date_str[:4]), int(date_str[5:7])
        severity = 'high' if pct > 10 else 'medium' if pct > 6 else 'low'
        explanation = (
            f"National electricity losses spiked to {pct:.1f}% of supply "
            f"({round(losses)} kWh) in this period of {y} — a statistically "
            f"abnormal jump (z-score above the tampering threshold) versus the "
            f"surrounding months. Consistent with large-scale meter tampering or "
            f"an unmetered draw. Recommend a grid-level investigation."
        )
        rows.append(('electricity_tampering', 'Malaysia', 'Potential tampering',
                     severity, explanation, s, c, losses, pct, y, 'electricity',
                     f'tampering:{y}-{m}'))
    history.append(losses)

rows.sort(key=lambda r: (r[10], r[0], -r[8]))

print('insert into public.alerts (')
print('  alert_type, state, detected_at, signature, severity, explanation, status,')
print('  is_deleted, produced_mld, billed_mld, loss_mld, loss_pct, data_year,')
print('  source_scope, utility_type, source_key')
print(') values')
values = []
for (alert_type, state, signature, severity, explanation,
     prod, bill, loss, pct, y, utility, key) in rows:
    values.append(
        f"  ('{alert_type}', '{sql_quote(state)}', now(), '{signature}', '{severity}',\n"
        f"   '{sql_quote(explanation)}',\n"
        f"   'pending_review', false, {prod:.4f}, {bill:.4f}, {loss:.4f}, {pct:.4f}, {y},\n"
        f"   'state', '{utility}', '{sql_quote(key)}')"
    )
print(',\n'.join(values))
print('on conflict (source_key) do nothing;')
