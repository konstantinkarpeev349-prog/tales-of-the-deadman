(()=>{'use strict';
  const teaser=document.querySelector('[data-dokains-archive-link]');if(!teaser)return;
  const init=async()=>{try{const account=await TODMAuth.getAccount();const access=account.access;if(account.session&&access&&!access.is_banned&&(access.full_access||Number(access.archive_level)>=1)){teaser.hidden=false;requestAnimationFrame(()=>teaser.querySelector('[data-reveal]')?.classList.add('visible'))}}catch(error){console.error('TODM archive link check failed:',error)}};
  if(window.TODMAuth)init();else addEventListener('todm-auth-ready',init,{once:true});
})();
