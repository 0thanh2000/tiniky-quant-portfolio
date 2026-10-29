import {cors,json,requireUser,secret} from './auth.ts';
export function handler(kind: 'chat'|'like'|'comment'|'follow') {
 return async (req: Request) => {
  if(req.method==='OPTIONS')return new Response('ok',{headers:cors});
  if(req.method!=='POST')return json({error:'Method not allowed'},405);
  try {
   const {user,client}=await requireUser(req);
   const body=await req.json();
   const profile=await client.from('profiles').select('username').eq('id',user.id).single();
   const name=profile.data?.username || 'Người dùng';
   let recipient='', text='', eventId='', eventTime='';
   const data: Record<string,unknown>={actor_id:user.id,actor_name:name};
   if(kind==='chat') {
    const conv=await client.from('conversations').select('user1,user2').eq('id',body.conversation_id).single();
    if(conv.error || ![conv.data.user1,conv.data.user2].includes(user.id))return json({error:'Forbidden'},403);
    recipient=conv.data.user1===user.id ? conv.data.user2 : conv.data.user1;
    const message=await client.from('messages').select('id,content,media,created_at').eq('conversation_id',body.conversation_id)
      .eq('sender_id',user.id).order('created_at',{ascending:false}).limit(1).single();
    if(message.error)return json({error:'No message'},400);
    text=message.data.content || (message.data.media?.kind==='video' ? 'Đã gửi video' : 'Đã gửi ảnh');
    eventId=message.data.id.toString();eventTime=message.data.created_at;
    Object.assign(data,{type:'chat',conversation_id:body.conversation_id});
   } else if(kind==='follow') {
    const follow=await client.from('follows').select('follower_id,following_id').eq('follower_id',user.id).eq('following_id',body.target_user_id).maybeSingle();
    if(!follow.data)return json({error:'No follow'},400);
    recipient=follow.data.following_id;text=`${name} đã theo dõi bạn`;eventId=recipient;
    Object.assign(data,{type:'follow'});
   } else {
    const post=await client.from('posts').select('user_id').eq('id',body.post_id).single();
    if(post.error)return json({error:'Post unavailable'},404);
    recipient=post.data.user_id;
    const query=client.from(kind==='like'?'likes':'comments').select(kind==='like'?'post_id':'id,content,media,created_at')
      .eq('post_id',body.post_id).eq('user_id',user.id);
    const event=kind==='like' ? await query.limit(1).maybeSingle() : await query.order('created_at',{ascending:false}).limit(1).maybeSingle();
    if(!event.data)return json({error:'No event'},400);
    eventId=kind==='like' ? body.post_id : event.data.id.toString();
    eventTime=event.data.created_at || '';
    text=kind==='like' ? `${name} đã thích bài viết của bạn` : `${name}: ${event.data.content || 'Đã bình luận bằng ảnh/video'}`;
    Object.assign(data,{type:kind==='like'?'like_post':'comment_post',post_id:body.post_id});
   }
   if(recipient===user.id)return json({skip:true});
   if(eventTime && Date.now()-Date.parse(eventTime)>5*60*1000)return json({skip:true});
   // A server-side claim deduplicates retries and limits notification spam.
   const claim=await client.rpc('app_claim_notification',{event_key:`${kind}:${eventId}`,target_user:recipient});
   if(claim.error || claim.data!==true)return json({skip:true});
   const response=await fetch('https://api.onesignal.com/notifications',{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Key ${secret('ONESIGNAL_REST_API_KEY')}`},
    body:JSON.stringify({app_id:secret('ONESIGNAL_APP_ID'),include_aliases:{external_id:[recipient]},target_channel:'push',
      headings:{en:kind==='chat'?name:'Tiniky'},contents:{en:text.slice(0,160)},data})});
   if(!response.ok)return json({error:'Push unavailable'},502);
   return json({success:true});
  } catch(e){return json({error:String(e).includes('Unauthorized')?'Unauthorized':'Notification unavailable'},String(e).includes('Unauthorized')?401:503);}
 };
}
