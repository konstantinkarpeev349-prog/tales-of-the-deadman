(()=>{'use strict';
  const css=document.createElement('link');css.rel='stylesheet';css.href='account-shop-prices.css';document.head.append(css);
  const init=async()=>{
    try{
      const account=await TODMAuth.getAccount();if(!account.session||!account.access?.is_author||account.access?.is_banned)return;
      const section=document.createElement('section');section.className='profile-card book-price-editor';section.dataset.shopPrices='';
      section.innerHTML='<p class="eyebrow">Управление магазином</p><h2>Цены печатных книг</h2><p>Том I — «Легенда о короле докаинов». Укажите ориентировочные цены в целых рублях.</p><form><label>Стандартное издание <input name="tome_1_standard" type="number" min="1" max="999999" step="1" required> ₽</label><label>Deluxe-издание <input name="tome_1_deluxe" type="number" min="1" max="999999" step="1" required> ₽</label><button type="submit">Сохранить изменения</button></form><p data-shop-price-message role="status" aria-live="polite"></p>';
      document.querySelector('.profile-settings').before(section);
      const form=section.querySelector('form'),message=section.querySelector('[data-shop-price-message]'),button=form.querySelector('button');
      const say=(value,isError=false)=>{message.textContent=value;message.dataset.error=String(isError)};
      const{data,error}=await TODMAuth.client.from('shop_book_prices').select('slug,price_rub').in('slug',['tome_1_standard','tome_1_deluxe']);
      if(error)throw error;
      for(const row of data){const input=form.elements.namedItem(row.slug);if(input)input.value=row.price_rub}
      form.addEventListener('submit',async event=>{
        event.preventDefault();
        const standard=Number(form.elements.namedItem('tome_1_standard').value),deluxe=Number(form.elements.namedItem('tome_1_deluxe').value);
        if(![standard,deluxe].every(value=>Number.isInteger(value)&&value>=1&&value<=999999)){say('Введите целые цены от 1 до 999 999 ₽.',true);return}
        button.disabled=true;say('Сохраняем цены…');
        try{const{error:saveError}=await TODMAuth.client.rpc('shop_update_book_prices',{p_standard:standard,p_deluxe:deluxe});if(saveError)throw saveError;say('ЦЕНЫ ОБНОВЛЕНЫ — новые цены опубликованы в магазине.')}catch(err){say(`Не удалось сохранить цены: ${TODMAuth.message(err)}`,true)}finally{button.disabled=false}
      });
    }catch(err){const section=document.querySelector('[data-shop-prices]');if(!section)return;const message=section.querySelector('[data-shop-price-message]');section.querySelector('form').hidden=true;message.textContent=`Цены недоступны: ${TODMAuth.message(err)}`;message.dataset.error='true'}
  };
  if(window.TODMAuth)init();else addEventListener('todm-auth-ready',init,{once:true});
})();
