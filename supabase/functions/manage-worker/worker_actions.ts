export type WorkerAction =
  | { action: 'create'; fullName: string; email: string }
  | { action: 'update'; workerId: string; fullName: string; email: string }
  | { action: 'activate' | 'deactivate'; workerId: string };

export const isActiveAdmin = (profile: {
  role: string;
  status: string;
}): boolean => profile.role === 'admin' && profile.status === 'active';

export function parseWorkerAction(value: unknown): WorkerAction {
  if (value == null || typeof value != 'object') {
    throw new Error('Request body must be an object');
  }

  const body = value as Record<string, unknown>;
  const action = body.action;
  const workerId = typeof body.workerId === 'string' ? body.workerId.trim() : '';
  const fullName = typeof body.fullName === 'string' ? body.fullName.trim() : '';
  const email = typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';

  if (action === 'create' && fullName && email) {
    return { action, fullName, email };
  }
  if (action === 'update' && workerId && fullName && email) {
    return { action, workerId, fullName, email };
  }
  if ((action === 'activate' || action === 'deactivate') && workerId) {
    return { action, workerId };
  }
  throw new Error('Invalid worker management request');
}
