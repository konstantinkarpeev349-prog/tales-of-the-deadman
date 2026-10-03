(()=>{'use strict';
  const output=document.querySelectorAll('[data-book-price]');
  if(!output.length)return;
  const load=async()=>{
    try{
      if(!window.TODMAuth)throw Error('Сервис цен недоступен');
      const{data,error}=await TODMAuth.client.from('shop_book_prices').select('slug,price_rub').in('slug',['tome_1_standard','tome_1_deluxe']);
      if(error)throw error;
      const prices=new Map(data.map(row=>[row.slug,row.price_rub]));
      for(const el of output){const price=prices.get(el.dataset.bookPrice);if(!Number.isInteger(price)||price<1)throw Error('Цена отсутствует')}
      for(const el of output)el.textContent=`${prices.get(el.dataset.bookPrice).toLocaleString('ru-RU')} ₽`;
    }catch(error){console.warn('TODM book prices unavailable',error);for(const el of output)el.textContent='Цена временно недоступна'}
  };
  if(window.TODMAuth)load();else{
    addEventListener('todm-auth-ready',load,{once:true});
    addEventListener('load',()=>{if(!window.TODMAuth)for(const el of output)el.textContent='Цена временно недоступна'},{once:true});
  }
})();
