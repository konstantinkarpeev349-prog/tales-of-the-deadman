(()=>{'use strict';
  const config=window.TODM_SUPABASE_CONFIG;
  const factory=window.supabase?.createClient;
  if(!config||!factory){console.error('TODM Auth: Supabase client is unavailable');return;}
  const client=factory(config.url,config.publishableKey,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true,flowType:'pkce'}});
  const getSession=async()=>{const{data,error}=await client.auth.getSession();if(error)throw error;return data.session};
  const getUser=async()=>{const{data,error}=await client.auth.getUser();if(error)throw error;return data.user};
  const getAccount=async()=>{const session=await getSession();if(!session)return{session:null,user:null,profile:null,access:null};const user=session.user;const[{data:profile,error:pe},{data:access,error:ae}]=await Promise.all([client.from('profiles').select('*').eq('user_id',user.id).maybeSingle(),client.from('account_access').select('*').eq('user_id',user.id).maybeSingle()]);if(pe)throw pe;if(ae)throw ae;return{session,user,profile,access}};
  const message=e=>e?.message||'Не удалось выполнить запрос';
  const listeners=new Set();let onlineIds=[];let presenceChannel=null;
  const emitPresence=()=>listeners.forEach(fn=>fn([...onlineIds]));
  const startPresence=async()=>{try{const session=await getSession();if(!session)return;presenceChannel=client.channel('todm-online',{config:{presence:{key:session.user.id}}});presenceChannel.on('presence',{event:'sync'},()=>{const state=presenceChannel.presenceState();onlineIds=Object.keys(state);emitPresence()}).subscribe(async status=>{if(status==='SUBSCRIBED')await presenceChannel.track({user_id:session.user.id,at:new Date().toISOString()})})}catch(error){console.warn('TODM presence unavailable',error)}};
  window.TODMPresence={getOnlineIds:()=>[...onlineIds],subscribe(fn){listeners.add(fn);fn([...onlineIds]);return()=>listeners.delete(fn)}};
  window.TODMAuth={client,getSession,getUser,getAccount,message};
  dispatchEvent(new CustomEvent('todm-auth-ready'));
  startPresence();
})();
addEventListener('todm-auth-ready',async()=>{try{if(!await TODMAuth.getSession())return;const page=location.pathname.split('/').pop();if(page==='SupportTickets.html'||page==='SupportTicket.html')await TODMAuth.client.rpc('support_mark_read')}catch(e){console.warn('TODM notification marker unavailable',e)}});
