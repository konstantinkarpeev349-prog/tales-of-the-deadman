(()=>{'use strict';
  const ready=()=>new Promise(resolve=>{if(window.TODMAuth)return resolve();addEventListener('todm-auth-ready',resolve,{once:true})});
  const escapeText=value=>String(value??'').replace(/[&<>"']/g,ch=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
  const render=async()=>{await ready();const navs=document.querySelectorAll('[data-nav]');if(!navs.length)return;let account=null;try{account=await TODMAuth.getAccount()}catch(error){console.warn('TODM account state unavailable',error)}const name=account?.profile?.display_name||account?.user?.email?.split('@')[0];navs.forEach(nav=>{let link=nav.querySelector('.account-link');if(!link){link=document.createElement('a');link.className='account-link';nav.append(link)}if(account?.session){link.href='Account.html';link.dataset.authState='user';link.setAttribute('aria-label','Открыть личный кабинет');link.innerHTML=`<span class="account-name">${escapeText(name||'Профиль')}</span>`}else{link.href='Auth.html';link.dataset.authState='guest';link.textContent='Войти'}});document.documentElement.dataset.auth=account?.session?'user':'guest';dispatchEvent(new CustomEvent('todm-account-state',{detail:account}))};
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',render,{once:true});else render();
  addEventListener('todm-auth-change',render);
})();
