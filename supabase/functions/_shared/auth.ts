import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

/**
 * Extracts and verifies the user JWT from the Authorization header.
 * Returns the authenticated user ID or throws a 401 error.
 */
export async function requireAuth(req: Request): Promise<string> {
  const authHeader = req.headers.get('Authorization');
  if (!authHeader?.startsWith('Bearer ')) {
    throw new AuthError('Missing or invalid Authorization header', 401);
  }

  const token = authHeader.replace('Bearer ', '');

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: `Bearer ${token}` } } },
  );

  const { data: { user }, error } = await supabase.auth.getUser();
  if (error || !user) {
    throw new AuthError('Invalid or expired JWT', 401);
  }

  return user.id;
}

export class AuthError extends Error {
  constructor(
    message: string,
    public readonly statusCode: number,
  ) {
    super(message);
    this.name = 'AuthError';
  }
}

/** Standard error response helper */
export function errorResponse(message: string, status: number, code?: string): Response {
  return new Response(
    JSON.stringify({ error: message, code: code ?? 'UNKNOWN_ERROR' }),
    { status, headers: { 'Content-Type': 'application/json' } },
  );
}

/** Standard success response helper */
export function jsonResponse(data: unknown, status = 200): Response {
  return new Response(
    JSON.stringify(data),
    { status, headers: { 'Content-Type': 'application/json' } },
  );
}
