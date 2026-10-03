(()=>{'use strict';
  async function mount(host){
    host.innerHTML='<div class="hub-price-editor"><p>Том I — «Легенда о короле докаинов». Цены в целых рублях.</p><form><label class="hub-field">Стандартное издание<input name="tome_1_standard" type="number" min="1" max="999999" step="1" required></label><label class="hub-field">Deluxe-издание<input name="tome_1_deluxe" type="number" min="1" max="999999" step="1" required></label><button class="hub-button primary" type="submit">Сохранить цены</button></form><p data-shop-price-message role="status" aria-live="polite"></p></div>';
    const form=host.querySelector('form'),message=host.querySelector('[data-shop-price-message]');
    const say=(value,error=false)=>{message.textContent=value;message.dataset.error=String(error)};
    try{
      const account=await TODMAuth.getAccount();if(!account.session||!account.access?.is_author||account.access?.is_banned)throw Error('Управление ценами доступно только Автору.');
      const {data,error}=await TODMAuth.client.from('shop_book_prices').select('slug,price_rub').in('slug',['tome_1_standard','tome_1_deluxe']);if(error)throw error;
      for(const row of data){const input=form.elements.namedItem(row.slug);if(input)input.value=row.price_rub}
      form.addEventListener('submit',async event=>{event.preventDefault();const standard=Number(form.elements.namedItem('tome_1_standard').value),deluxe=Number(form.elements.namedItem('tome_1_deluxe').value);if(![standard,deluxe].every(value=>Number.isInteger(value)&&value>=1&&value<=999999)){say('Введите целые цены от 1 до 999 999 ₽.',true);return}const button=form.querySelector('button');button.disabled=true;say('Сохраняем цены…');try{const{error:saveError}=await TODMAuth.client.rpc('shop_update_book_prices',{p_standard:standard,p_deluxe:deluxe});if(saveError)throw saveError;say('Цены обновлены.')}catch(err){say(`Не удалось сохранить: ${TODMAuth.message(err)}`,true)}finally{button.disabled=false}});
    }catch(err){form.hidden=true;say(`Цены недоступны: ${TODMAuth.message(err)}`,true)}
  }
  window.TODMShopPrices={mount};
})();
