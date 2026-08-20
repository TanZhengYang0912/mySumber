import { assertEquals, assertThrows } from 'jsr:@std/assert@1';

import { anomalyPrompt, parseAlertId, parseGroqAnalysis } from './anomaly_ai.ts';

Deno.test('accepts a positive integer alert id', () => {
  assertEquals(parseAlertId({alert_id: 42}), 42);
  assertThrows(() => parseAlertId({alert_id: '42'}));
});

Deno.test('validates structured Groq JSON', () => {
  const response = {
    choices: [
      {
        message: {
          content: JSON.stringify({
            summary: 'Pump usage is above baseline.',
            possible_cause: 'Continuous demand spike.',
            severity_assessment: 'High',
            confidence: 0.9,
            recommendation: 'Inspect the equipment record.',
          }),
        },
      },
    ],
  };

  assertEquals(parseGroqAnalysis(response).severity_assessment, 'High');
});

Deno.test('builds prompts from server-fetched alert data', () => {
  const prompt = anomalyPrompt({
    utility_type: 'water',
    state: 'Selangor',
    facility_name: '1 Utama Shopping Centre',
    equipment_name: 'Main Water Pump A1',
  });
  assertEquals(prompt.includes('Main Water Pump A1'), true);
  assertEquals(prompt.includes('Water'), true);
});

Deno.test('derives utility from alert_type, not a nonexistent column', () => {
  const waterPrompt = anomalyPrompt({
    alert_type: 'nrw_hotspot',
    state: 'Perlis',
  });
  assertEquals(waterPrompt.includes('Utility: Water'), true);

  const electricityPrompt = anomalyPrompt({
    alert_type: 'electricity_hotspot',
    state: 'Selangor',
  });
  assertEquals(electricityPrompt.includes('Utility: Electricity'), true);
});

Deno.test('preview evidence produces the same prompt shape as an alert row', () => {
  const promptFromRow = anomalyPrompt({alert_type: 'nrw_hotspot', state: 'Perlis', explanation: 'Test.'});
  const promptFromPreview = anomalyPrompt({alert_type: 'nrw_hotspot', state: 'Perlis', explanation: 'Test.'});
  assertEquals(promptFromRow, promptFromPreview);
});
