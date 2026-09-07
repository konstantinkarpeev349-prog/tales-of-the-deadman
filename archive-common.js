(()=>{'use strict';
  const rank=access=>access?.full_access?3:Number(access?.archive_level||0);
  const can=(access,required)=>Boolean(access&&!access.is_banned&&(access.full_access||Number(access.archive_level)>=required));
  const waitAuth=()=>window.TODMAuth?Promise.resolve():new Promise(resolve=>addEventListener('todm-auth-ready',resolve,{once:true}));
  const account=async()=>{await waitAuth();return TODMAuth.getAccount()};
  const gate=(root,required,current,next)=>{const guest=!current?.session;root.innerHTML=`<section class="archive-gate"><div class="seal"><span>${required}</span></div><p class="eyebrow">Архив TODM</p><h1>${guest?'ТРЕБУЕТСЯ АВТОРИЗАЦИЯ':`ТРЕБУЕТСЯ УРОВЕНЬ ДОПУСКА ${required}`}</h1><p>${guest?'Войдите в аккаунт, чтобы Архив смог проверить ваш уровень допуска.':'Ваш текущий уровень не позволяет открыть это хранилище.'}</p><div class="archive-gate-actions">${guest?`<a class="button" href="Auth.html?next=${encodeURIComponent(next)}">Войти</a>`:'<a class="button" href="Account.html">Перейти в кабинет</a>'}<a href="Archive.html">Вернуться в Архив</a></div></section>`};
  window.TODMArchive={rank,can,account,gate};
})();
