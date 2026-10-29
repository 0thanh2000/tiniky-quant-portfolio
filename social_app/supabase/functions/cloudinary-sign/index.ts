import {cors, json, requireUser, secret} from '../_shared/auth.ts';
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', {headers: cors});
  if (req.method !== 'POST') return json({error: 'Method not allowed'}, 405);
  try {
    const {user, client} = await requireUser(req);
    const body = await req.json();
    if (!['image','video'].includes(body.kind)) return json({error: 'Invalid media kind'},400);
    // Atomic per-user throttle prevents unlimited requests for signed uploads.
    const quota = await client.rpc('app_upload_permit');
    if (quota.error) return json({error: 'Upload limit reached. Try again later.'},429);
    const params: Record<string,string> = {
      timestamp: Math.floor(Date.now()/1000).toString(),
      public_id: `social-app/${user.id}/${crypto.randomUUID()}`,
      upload_preset: secret('CLOUDINARY_SIGNED_PRESET'),
      overwrite: 'false',
    };
    const payload = Object.keys(params).sort().map(k => `${k}=${params[k]}`).join('&') + secret('CLOUDINARY_API_SECRET');
    const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(payload));
    const signature = Array.from(new Uint8Array(digest)).map(b => b.toString(16).padStart(2,'0')).join('');
    return json({cloud_name: secret('CLOUDINARY_CLOUD_NAME'), api_key: secret('CLOUDINARY_API_KEY'), params, signature});
  } catch (e) {
    const msg = String(e);
    return json({error: msg.includes('Unauthorized') ? 'Unauthorized' : 'Upload configuration unavailable'}, msg.includes('Unauthorized') ? 401 : 503);
  }
});
