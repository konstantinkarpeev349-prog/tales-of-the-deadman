(()=>{'use strict';
  const forms=[...document.querySelectorAll('[data-auth-form]')],tabs=[...document.querySelectorAll('[data-auth-mode]')],message=document.querySelector('[data-auth-message]');
  const show=(text='',error=false)=>{message.textContent=text;message.classList.toggle('error',error)};
  const mode=name=>{forms.forEach(form=>form.hidden=form.dataset.authForm!==name);document.querySelectorAll('.auth-tabs [data-auth-mode]').forEach(btn=>btn.setAttribute('aria-selected',String(btn.dataset.authMode===name)));show()};
  tabs.forEach(btn=>btn.addEventListener('click',()=>mode(btn.dataset.authMode)));
  const redirect=()=>{const value=new URLSearchParams(location.search).get('next');if(!value||value.includes('://')||value.startsWith('//'))return'Account.html';return value};
  const init=async()=>{const params=new URLSearchParams(location.search);if(params.get('mode')==='reset'||location.hash.includes('type=recovery'))mode('reset');else if(await TODMAuth.getSession())location.replace(redirect())};if(window.TODMAuth)init();else addEventListener('todm-auth-ready',init,{once:true});
  forms.forEach(form=>form.addEventListener('submit',async event=>{event.preventDefault();show();const submit=form.querySelector('[type=submit]');submit.disabled=true;const values=Object.fromEntries(new FormData(form));try{
    if(form.dataset.authForm==='login'){const{error}=await TODMAuth.client.auth.signInWithPassword({email:values.email.trim(),password:values.password});if(error)throw error;location.href=redirect()}
    if(form.dataset.authForm==='register'){const{data,error}=await TODMAuth.client.auth.signUp({email:values.email.trim(),password:values.password,options:{data:{display_name:values.display_name.trim()}}});if(error)throw error;if(!data.session)show('Аккаунт создан. Проверьте электронную почту.');else location.href=redirect()}
    if(form.dataset.authForm==='recover'){const target=new URL('Auth.html?mode=reset',location.href).href;const{error}=await TODMAuth.client.auth.resetPasswordForEmail(values.email.trim(),{redirectTo:target});if(error)throw error;show('Ссылка для восстановления отправлена.')}
    if(form.dataset.authForm==='reset'){if(values.password!==values.password_repeat)throw new Error('Пароли не совпадают');const{error}=await TODMAuth.client.auth.updateUser({password:values.password});if(error)throw error;show('Пароль изменён. Сейчас откроется личный кабинет.');setTimeout(()=>location.href='Account.html',900)}
  }catch(error){show(TODMAuth.message(error),true)}finally{submit.disabled=false}}));
})();
