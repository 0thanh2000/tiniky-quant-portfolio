import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
export const cors = {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS'};
export function json(value: unknown, status = 200) {
  return new Response(JSON.stringify(value), {status, headers: {...cors, 'Content-Type': 'application/json'}});
}
export async function requireUser(req: Request) {
  const authorization = req.headers.get('Authorization');
  if (!authorization?.startsWith('Bearer ')) throw new Error('Unauthorized');
  const client = createClient(secret('SUPABASE_URL'), publishableKey(),
    {global: {headers: {Authorization: authorization}}, auth: {persistSession: false}});
  const {data, error} = await client.auth.getUser();
  if (error || !data.user) throw new Error('Unauthorized');
  return {user: data.user, client};
}
function publishableKey() {
  const configured = Deno.env.get('SUPABASE_PUBLISHABLE_KEY');
  if (configured) return configured;
  const named = Deno.env.get('SUPABASE_PUBLISHABLE_KEYS');
  if (named) {
    const values = JSON.parse(named) as Record<string, unknown>;
    const key = Object.values(values).find((value) => typeof value === 'string' && value.startsWith('sb_publishable_'));
    if (typeof key === 'string') return key;
  }
  return secret('SUPABASE_ANON_KEY');
}
export function secret(name: string) {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing server configuration: ${name}`);
  return value;
}
