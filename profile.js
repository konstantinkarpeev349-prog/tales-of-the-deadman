(()=>{'use strict';
  const labels={paladins:'Паладины',frauster:'Фраустер',maizervin:'Майзервин',doronto:'Культ Доронто',dokains:'Докаины'};
  const loading=document.querySelector('[data-profile-loading]'),shell=document.querySelector('[data-profile]'),msg=document.querySelector('[data-profile-message]');let account;
  const say=(text,error=false)=>{msg.textContent=text;msg.style.color=error?'#cf8174':''};
  const ranks=['','I','II','III','IV','V'];
  const level=value=>ranks[value]?`${ranks[value]} уровень`:'Базовый доступ';
  const defaultAvatar=name=>{const letter=encodeURIComponent((name||'T').slice(0,1).toUpperCase());return`data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='512' height='512'%3E%3Crect width='512' height='512' fill='%23130f0c'/%3E%3Cpath d='M256 40 472 256 256 472 40 256Z' fill='none' stroke='%23ad925f' stroke-width='5'/%3E%3Ctext x='256' y='300' text-anchor='middle' font-family='serif' font-size='150' fill='%23d6c8ad'%3E${letter}%3C/text%3E%3C/svg%3E`};
  const badges=access=>{const values=[];if(access?.is_author)values.push(['Автор','author']);if(access?.is_todm_team)values.push(['TODM','todm']);if(access?.is_supporter)values.push(['Поддержал','']);const rank=ranks[access?.archive_level];if(rank)values.push([rank,'']);return values.map(([text,kind])=>`<span class="badge ${kind}">${text}</span>`).join('')};
  const init=async()=>{try{account=await TODMAuth.getAccount();if(!account.session){location.replace(`Auth.html?next=${encodeURIComponent('Account.html')}`);return}const name=account.profile?.display_name||account.user.email.split('@')[0];document.querySelector('[data-display-name]').textContent=name;document.querySelector('[data-email]').textContent=account.user.email;document.querySelector('[data-avatar]').src=account.profile?.avatar_url||defaultAvatar(name);document.querySelector('[data-badges]').innerHTML=badges(account.access);document.querySelector('[data-archive-status]').textContent=account.access?.full_access?'Полный доступ':level(account.access?.archive_level||0);const faction=account.profile?.selected_faction||'';document.querySelector('[name=selected_faction]').value=faction;document.querySelector('[data-faction-label]').textContent=labels[faction]||'Не выбрана';document.querySelector('[data-name-form] input').value=name;await loadHistory();if(account.access?.is_admin&&!account.access.is_banned){const link=document.createElement('a');link.href='Admin.html';link.textContent='Управление пользователями';link.className='admin-entry';document.querySelector('.profile-settings').prepend(link)}if((account.access?.is_todm_team||account.access?.is_admin)&&!account.access.is_banned){const link=document.createElement('a');link.href='Staff.html';link.textContent='Ранги читателей (0–III)';link.className='admin-entry';document.querySelector('.profile-settings').prepend(link)}loading.hidden=true;shell.hidden=false}catch(error){loading.textContent=`Не удалось загрузить профиль: ${TODMAuth.message(error)}`;console.error('TODM profile load failed:',error?.message,error?.code,error?.details)}};
  const loadHistory=async()=>{const[{data:support},{data:orders}]=await Promise.all([TODMAuth.client.from('support_payments').select('amount,currency,paid_at').eq('status','succeeded').order('paid_at',{ascending:false}).limit(10),TODMAuth.client.from('orders').select('id,total_amount,status,created_at').order('created_at',{ascending:false}).limit(10)]);if(support?.length)document.querySelector('[data-support]').innerHTML=support.map(row=>`<div class="support-entry"><b>${(row.amount/100).toLocaleString('ru-RU')} ₽</b><span>${new Date(row.paid_at).toLocaleDateString('ru-RU')}</span></div>`).join('');if(orders?.length)document.querySelector('[data-purchases]').innerHTML=orders.map(row=>`<div class="support-entry"><b>Заказ ${String(row.id).slice(0,8)}</b><span>${(row.total_amount/100).toLocaleString('ru-RU')} ₽</span></div>`).join('')};
  document.querySelector('[data-faction-form]').addEventListener('submit',async e=>{e.preventDefault();const value=new FormData(e.currentTarget).get('selected_faction')||null;const{error}=await TODMAuth.client.from('profiles').update({selected_faction:value}).eq('user_id',account.user.id);if(error)return say(TODMAuth.message(error),true);document.querySelector('[data-faction-label]').textContent=labels[value]||'Не выбрана';say('Фракция сохранена.')});
  document.querySelector('[data-name-form]').addEventListener('submit',async e=>{e.preventDefault();const value=new FormData(e.currentTarget).get('display_name').trim();const{error}=await TODMAuth.client.from('profiles').update({display_name:value}).eq('user_id',account.user.id);if(error)return say(error.code==='23505'?'Этот ник уже занят.':TODMAuth.message(error),true);document.querySelector('[data-display-name]').textContent=value;say('Ник сохранён.');dispatchEvent(new CustomEvent('todm-auth-change'))});
  const avatarInput=document.querySelector('[data-avatar-input]');
  const avatarButton=document.querySelector('[data-avatar-change]');
  let avatarBusy=false;
  avatarButton.addEventListener('click',()=>{if(!avatarBusy)avatarInput.click()});
  avatarInput.addEventListener('change',async e=>{
    const file=e.target.files[0];if(!file||avatarBusy)return;
    avatarBusy=true;avatarButton.disabled=true;
    try{
      if(!file.size)throw new Error('Файл пуст. Выберите другое изображение.');
      if(file.size>5*1024*1024)throw new Error('Изображение больше 5 МБ. Уменьшите его размер и повторите загрузку.');
      const types={'image/jpeg':'jpg','image/png':'png','image/webp':'webp'};
      const extension=(file.name.split('.').pop()||'').toLowerCase();
      const fallback={jpg:'image/jpeg',jpeg:'image/jpeg',png:'image/png',webp:'image/webp'};
      const mime=file.type==='image/jpg'?'image/jpeg':(!file.type||file.type==='application/octet-stream'?fallback[extension]:file.type);
      if(!types[mime])throw new Error('Поддерживаются JPG, PNG и WebP. HEIC и другие форматы сначала сохраните как JPG.');
      const session=await TODMAuth.getSession();
      if(!session)throw new Error('Сессия завершилась. Войдите в аккаунт снова.');
      const path=`${session.user.id}/avatar.${types[mime]}`;
      say('Загружаем аватар…');
      const{error}=await TODMAuth.client.storage.from('avatars').upload(path,file,{upsert:true,contentType:mime});
      if(error)throw error;
      const{data}=TODMAuth.client.storage.from('avatars').getPublicUrl(path);
      const avatar_url=`${data.publicUrl}?v=${Date.now()}`;
      const{error:updateError}=await TODMAuth.client.from('profiles').update({avatar_url}).eq('user_id',session.user.id).select('user_id').single();
      if(updateError)throw updateError;
      document.querySelector('[data-avatar]').src=avatar_url;
      say('Аватар обновлён.');
    }catch(error){
      const detail=TODMAuth.message(error);
      say(/row.level security|permission denied/i.test(detail)?'Нет доступа к сохранению аватара. Обратитесь к команде TODM.':`Не удалось загрузить аватар: ${detail}`,true);
    }finally{avatarInput.value='';avatarBusy=false;avatarButton.disabled=false}
  });
  document.querySelector('[data-logout]').addEventListener('click',async()=>{await TODMAuth.client.auth.signOut();location.href='index.html'});if(window.TODMAuth)init();else addEventListener('todm-auth-ready',init,{once:true});
})();

(()=>{'use strict';
  const ranks=['0','I','II','III','IV','V'];
  const init=async()=>{try{const account=await TODMAuth.getAccount();if(!account.session)return;const{data,error}=await TODMAuth.client.from('rank_promotion_notifications').select('new_level').is('seen_at',null).maybeSingle();if(error)throw error;if(!data)return;const modal=document.createElement('div');modal.className='rank-promotion';modal.setAttribute('role','dialog');modal.setAttribute('aria-modal','true');modal.setAttribute('aria-labelledby','promotion-title');modal.innerHTML=`<div class="promotion-panel"><span class="promotion-seal" aria-hidden="true">TODM</span><p class="eyebrow">Уведомление Архива</p><h2 id="promotion-title">Архив отметил ваш вклад в развитие</h2><p>Поздравляем. Ваш ранг повышен.</p><strong>Новый ранг: ${ranks[data.new_level]||data.new_level}</strong><p>Вам стали доступны новые секретные материалы Архива.</p><div><a href="Tom_I.html">Открыть новые материалы</a><button type="button">Принять уведомление</button></div></div>`;document.body.append(modal);const button=modal.querySelector('button');button.focus();button.onclick=async()=>{button.disabled=true;const{error:updateError}=await TODMAuth.client.from('rank_promotion_notifications').update({seen_at:new Date().toISOString()}).eq('user_id',account.user.id).is('seen_at',null);if(updateError){button.disabled=false;return}modal.remove()}}catch(error){console.error('Rank promotion notification failed:',error)}};
  if(window.TODMAuth)init();else addEventListener('todm-auth-ready',init,{once:true});
})();
