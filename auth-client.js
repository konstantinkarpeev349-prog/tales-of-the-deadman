(()=>{'use strict';
  const config=window.TODM_SUPABASE_CONFIG;
  const factory=window.supabase?.createClient;
  if(!config||!factory){console.error('TODM Auth: Supabase client is unavailable');return;}
  const page=location.pathname.split('/').pop()||'index.html';
  const protectedPage=/^(?:Account|Customization|Admin[^/]*|Staff|Chat|Community|FactionChat|Messages|Dialog|Online|User|SupportTickets?|Archive_[^/]*|Dokains_Archive|Tome_II_[^/]*)\.html$/i.test(page);
  if(protectedPage){
    const conceal=document.createElement('style');
    conceal.textContent='body.todm-ban-pending > :not(#todm-ban-screen),body.todm-ban-locked > :not(#todm-ban-screen){display:none!important}';
    document.head.append(conceal);document.body.classList.add('todm-ban-pending');
    const sheet=document.createElement('link');sheet.rel='stylesheet';sheet.href='ban-screen.css?v=1';document.head.append(sheet);
  }
  const nativeFetch=globalThis.fetch.bind(globalThis),base=new URL(config.url);
  let client,banState='unknown',banAccess=null,banUser=null,lastBanCheck=0,banCheckPromise=null,banCheckFailed=false;
  const guardedFetch=async(input,init)=>{
    const target=new URL(typeof input==='string'?input:input.url,location.href);
    const api=target.origin===base.origin&&target.pathname.startsWith(base.pathname.replace(/\/$/,'')+'/');
    const rest=api&&target.pathname.includes('/rest/v1/');
    const storage=api&&target.pathname.includes('/storage/v1/');
    const statusLookup=rest&&target.pathname.endsWith('/rest/v1/account_access')
      &&target.searchParams.get('select')==='is_banned'&&(!init?.method||init.method==='GET');
    if((rest||storage)&&!statusLookup){
      const status=await checkBan(true);
      if(status.state==='banned')throw Error('Доступ к аккаунту ограничен');
      if(status.state==='unknown')throw Error('Не удалось проверить доступ');
    }
    return nativeFetch(input,init);
  };
  client=factory(config.url,config.publishableKey,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true,flowType:'pkce'},global:{fetch:guardedFetch}});
  const getSession=async()=>{const{data,error}=await client.auth.getSession();if(error)throw error;return data.session};
  const getUser=async()=>{const{data,error}=await client.auth.getUser();if(error)throw error;return data.user};
  const getAccount=async()=>{
    const status=await checkBan(true);
    const session=await getSession();
    if(!session)return{session:null,user:null,profile:null,access:null};
    if(status.state==='banned')throw Error('Доступ к аккаунту ограничен');
    if(status.state!=='active')throw Error('Не удалось проверить доступ');
    const[{data:profile,error:profileError},{data:access,error:accessError}]=await Promise.all([
      client.from('profiles').select('*').eq('user_id',session.user.id).maybeSingle(),
      client.from('account_access').select('*').eq('user_id',session.user.id).maybeSingle()
    ]);
    if(profileError||accessError)throw profileError||accessError;
    if(!access){setBanState('unknown');throw Error('Не удалось проверить доступ')}
    if(access.is_banned){setBanState('banned',{is_banned:true});throw Error('Доступ к аккаунту ограничен')}
    return{session,user:session.user,profile,access};
  };
  const message=e=>e?.message||'Не удалось выполнить запрос';
  const listeners=new Set();let onlineIds=[];let presenceChannel=null;
  const emitPresence=()=>listeners.forEach(fn=>fn([...onlineIds]));
  const stopSubscriptions=()=>{presenceChannel=null;onlineIds=[];emitPresence();client.removeAllChannels().catch(()=>{})};
  const showBanScreen=kind=>{
    if(!protectedPage)return;
    document.body.classList.add('todm-ban-locked');document.body.classList.remove('todm-ban-pending');
    let panel=document.querySelector('#todm-ban-screen');
    if(!panel){
      panel=document.createElement('main');panel.id='todm-ban-screen';panel.className='todm-ban-screen';
      panel.innerHTML='<section class="todm-ban-card"><p class="todm-ban-eyebrow">TODM · уведомление</p><div class="todm-ban-seal" aria-hidden="true">!</div><h1 data-ban-title></h1><p data-ban-text></p><div class="todm-ban-actions"><button type="button" data-ban-retry>Проверить снова</button><button type="button" data-ban-logout>Выйти из аккаунта</button><a href="Kontakt.html">Связаться с администрацией</a></div></section>';
      document.body.append(panel);
      panel.querySelector('[data-ban-retry]').onclick=()=>checkBan(true).catch(()=>{});
      panel.querySelector('[data-ban-logout]').onclick=async()=>{await client.auth.signOut();location.href='index.html'};
    }
    panel.querySelector('[data-ban-title]').textContent=kind==='banned'?'Доступ к аккаунту ограничен':'Не удалось проверить доступ';
    panel.querySelector('[data-ban-text]').textContent=kind==='banned'
      ?'Ваш аккаунт заблокирован администрацией TODM. Возможности личного кабинета и участие в активности проекта временно недоступны.'
      :'Связь с сервером временно недоступна. Закрытые разделы не открыты. Повторите проверку.';
    panel.querySelector('[data-ban-retry]').hidden=kind==='banned';
  };
  const setBanState=(next,row=null)=>{
    const previous=banState;banState=next;banAccess=row;
    if(next==='banned'||next==='unknown'){
      stopSubscriptions();showBanScreen(next);
    }else if(next==='active'){
      document.body.classList.remove('todm-ban-pending','todm-ban-locked');
      document.querySelector('#todm-ban-screen')?.remove();
      if(previous==='banned'||banCheckFailed){banCheckFailed=false;location.reload();return}
    }else{
      stopSubscriptions();document.body.classList.remove('todm-ban-locked');
      document.querySelector('#todm-ban-screen')?.remove();
      if(protectedPage&&(previous==='active'||previous==='banned')){
        document.body.classList.add('todm-ban-pending');location.href='index.html';
      }else document.body.classList.remove('todm-ban-pending');
    }
    if(previous!==next)dispatchEvent(new CustomEvent('todm-ban-state',{detail:{state:next}}));
  };
  const checkBan=async(force=false)=>{
    if(banCheckPromise)return banCheckPromise;
    if(!force&&Date.now()-lastBanCheck<5000&&banState==='active')return{state:banState,access:banAccess};
    banCheckPromise=(async()=>{
      try{
        const session=await getSession();
        if(!session){banUser=null;lastBanCheck=Date.now();setBanState('guest');return{state:'guest',access:null}}
        if(banUser!==session.user.id){banUser=session.user.id;lastBanCheck=0}
        const{data,error}=await client.from('account_access').select('is_banned').eq('user_id',banUser).maybeSingle();
        if(error)throw error;
        if(!data||typeof data.is_banned!=='boolean')throw Error('Статус аккаунта не получен');
        lastBanCheck=Date.now();setBanState(data.is_banned?'banned':'active',data);
        return{state:banState,access:data};
      }catch(error){lastBanCheck=0;banCheckFailed=true;setBanState('unknown');throw error}
      finally{banCheckPromise=null}
    })();
    return banCheckPromise;
  };
  const originalChannel=client.channel.bind(client);
  const originalRpc=client.rpc.bind(client);
  client.rpc=async(...args)=>{
    try{const status=await checkBan(true);if(status.state==='banned')return{data:null,error:Error('Доступ к аккаунту ограничен')};return originalRpc(...args)}
    catch(error){return{data:null,error}}
  };
  const inactiveChannel=()=>{const stub={on:()=>stub,subscribe(callback){callback?.('CHANNEL_ERROR');return stub},track:async()=>({error:Error('Доступ недоступен')}),unsubscribe:async()=>{}};return stub};
  client.channel=(...args)=>banState==='active'?originalChannel(...args):inactiveChannel();
  const originalUpdateUser=client.auth.updateUser.bind(client.auth);
  client.auth.updateUser=async(...args)=>{
    try{const status=await checkBan(true);if(status.state==='banned'||status.state==='unknown')return{data:{user:null},error:Error('Доступ к аккаунту ограничен')};return originalUpdateUser(...args)}
    catch(error){return{data:{user:null},error}}
  };
  const startPresence=async()=>{try{if(banState!=='active'||presenceChannel)return;const session=await getSession();if(!session||banState!=='active')return;presenceChannel=client.channel('todm-online',{config:{presence:{key:session.user.id}}});presenceChannel.on('presence',{event:'sync'},()=>{onlineIds=Object.keys(presenceChannel.presenceState());emitPresence()}).subscribe(async status=>{if(status==='SUBSCRIBED'&&banState==='active')await presenceChannel.track({user_id:session.user.id,at:new Date().toISOString()})})}catch(error){console.warn('TODM presence unavailable',error)}};
  window.TODMPresence={getOnlineIds:()=>[...onlineIds],subscribe(fn){listeners.add(fn);fn([...onlineIds]);return()=>listeners.delete(fn)}};
  window.TODMAuth={client,getSession,getUser,getAccount,checkBan,message,get banState(){return banState}};
  dispatchEvent(new CustomEvent('todm-auth-ready'));
  const boot=async()=>{try{
    const status=await checkBan(true);if(status.state!=='active')return;
    await startPresence();
    for(const src of ['leadership-notification.js?v=2','warning-notification.js?v=1','archive-activity.js?v=1']){
      const script=document.createElement('script');script.src=src;script.defer=true;document.head.append(script);
    }
    if(page==='SupportTickets.html'||page==='SupportTicket.html')await client.rpc('support_mark_read');
  }catch(error){console.warn('TODM account status unavailable',error)}};
  boot();
  setInterval(()=>{if(document.visibilityState==='visible')checkBan(true).catch(()=>{})},15000);
  addEventListener('focus',()=>checkBan(true).catch(()=>{}));
  client.auth.onAuthStateChange(event=>{
    if(event==='SIGNED_OUT'){banUser=null;lastBanCheck=0;setBanState('guest');return}
    if(event==='SIGNED_IN'||event==='TOKEN_REFRESHED')setTimeout(()=>checkBan(true).catch(()=>{}),0);
  });
})();
