import { assertEquals, assertThrows } from 'jsr:@std/assert@1';

import { isActiveAdmin, parseWorkerAction } from './worker_actions.ts';

Deno.test('accepts a worker invitation with name and email', () => {
  assertEquals(
    parseWorkerAction({
      action: 'create',
      fullName: 'Nur Aisyah',
      email: 'nur.aisyah@mysumber.my',
    }),
    {
    action: 'create',
    fullName: 'Nur Aisyah',
    email: 'nur.aisyah@mysumber.my',
    },
  );
});

Deno.test('rejects a status change without a worker id', () => {
  assertThrows(() => parseWorkerAction({ action: 'deactivate' }));
});

Deno.test('requires an active admin profile', () => {
  assertEquals(isActiveAdmin({ role: 'admin', status: 'active' }), true);
  assertEquals(isActiveAdmin({ role: 'admin', status: 'inactive' }), false);
  assertEquals(isActiveAdmin({ role: 'worker', status: 'active' }), false);
});
