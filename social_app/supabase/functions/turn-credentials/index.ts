import {cors, json, requireUser, secret} from '../_shared/auth.ts';
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', {headers: cors});
  if (req.method !== 'POST') return json({error: 'Method not allowed'},405);
  try {
    const {user} = await requireUser(req);
    // coturn REST authentication. Never embed a long-lived TURN password in Flutter.
    const host = secret('TURN_HOST');
    if (!/^[a-zA-Z0-9.-]+$/.test(host)) return json({error:'Invalid TURN host'},503);
    const username = `${Math.floor(Date.now()/1000)+3600}:${user.id}`;
    const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret('TURN_SHARED_SECRET')),
      {name:'HMAC',hash:'SHA-1'}, false, ['sign']);
    const bytes = new Uint8Array(await crypto.subtle.sign('HMAC',key,new TextEncoder().encode(username)));
    const credential = btoa(String.fromCharCode(...bytes));
    return json({iceServers:[
      {urls:[`stun:${host}:3478`]},
      {urls:[`turn:${host}:3478?transport=udp`,`turn:${host}:3478?transport=tcp`,`turns:${host}:5349?transport=tcp`],username,credential},
    ]});
  } catch (e) {
    return json({error:String(e).includes('Unauthorized') ? 'Unauthorized' : 'TURN is not configured'},String(e).includes('Unauthorized') ? 401 : 503);
  }
});
