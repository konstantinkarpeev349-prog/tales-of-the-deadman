(()=>{'use strict';
const $=s=>document.querySelector(s),status=$('#status');let offset=0,query='',busy=false;
const say=t=>status.textContent=t;
const el=(tag,text,cls)=>{const n=document.createElement(tag);if(text)n.textContent=text;if(cls)n.className=cls;return n};
const ranks=['0 — базовый','I','II','III','IV — сотрудник','V — владелец'];
function render(row){
 const card=el('article',null,'admin-user'),heading=el('h2',row.display_name||'Без ника');card.append(heading,el('p',row.email,'email'));
 if(row.is_todm_team)card.append(el('span','TODM','badge todm'));if(row.is_author)card.append(el('span','Автор','badge author'));
 const form=el('form',null,'admin-fields'),level=el('select');level.setAttribute('aria-label','Ранг');ranks.forEach((name,i)=>{if(i===5&&row.archive_level!==5)return;const o=el('option',name);o.value=i;level.append(o)});level.value=row.archive_level;const lab=el('label','Уровень');lab.append(level);form.append(lab);
 const check=(title,value)=>{const l=el('label',title),input=el('input');input.type='checkbox';input.checked=value;l.prepend(input);form.append(l);return input};
 const team=check('Плашка TODM',row.is_todm_team),full=check('Полный доступ',row.full_access),ban=check('Заблокирован',row.is_banned),save=el('button','Сохранить');save.type='submit';form.append(save);
 const sync=()=>{team.checked=Number(level.value)>=4;if(team.checked)full.checked=true;full.disabled=team.checked};
 level.addEventListener('change',sync);team.addEventListener('change',()=>{level.value=team.checked?'4':'0';full.checked=team.checked;sync()});sync();
 if(row.is_admin||row.archive_level===5){form.querySelectorAll('input,select,button').forEach(n=>n.disabled=true);card.append(el('p','Защищённый аккаунт администратора / владельца'));}
 form.addEventListener('submit',async e=>{e.preventDefault();if(busy)return;if(!confirm(`Сохранить права пользователя ${row.email}? Уровень: ${ranks[Number(level.value)]}. TODM: ${team.checked?'да':'нет'}. Полный доступ: ${full.checked?'да':'нет'}. Бан: ${ban.checked?'да':'нет'}.`))return;
 busy=true;save.disabled=true;say('Сохраняем…');try{const{error}=await TODMAuth.client.rpc('admin_update_access',{p_user_id:row.user_id,p_level:Number(level.value),p_team:team.checked,p_full:full.checked,p_banned:ban.checked,p_updated_at:row.updated_at});if(error)throw error;await load();say('Изменения сохранены.');}catch(e){say(`Не удалось сохранить: ${TODMAuth.message(e)}`)}finally{busy=false;save.disabled=false}});
 card.append(form);return card;
}
async function load(){const{data,error}=await TODMAuth.client.rpc('admin_list_users',{p_search:query,p_offset:offset});if(error){$('#users').replaceChildren();throw error}$('#users').replaceChildren(...data.map(render));$('#prev').disabled=offset===0;$('#next').disabled=data.length<50;$('#page').textContent=`Страница ${offset/50+1}`;say(data.length?'Список загружен.':'Пользователи не найдены.');}
async function navigate(delta){if(busy)return;busy=true;offset=Math.max(0,offset+delta);try{await load()}catch(e){say(TODMAuth.message(e))}finally{busy=false}}
$('#search').addEventListener('submit',e=>{e.preventDefault();if(busy)return;query=new FormData(e.currentTarget).get('query').trim();offset=0;navigate(0)});$('#prev').onclick=()=>navigate(-50);$('#next').onclick=()=>navigate(50);
async function init(){try{const a=await TODMAuth.getAccount();if(!a.session){location.replace('Auth.html?next=Admin.html');return}if(!a.access?.is_admin||a.access.is_banned){say('Доступ только для администратора.');return}await load();$('#panel').hidden=false}catch(e){say(`Панель недоступна: ${TODMAuth.message(e)}`)}}
if(window.TODMAuth)init();else addEventListener('todm-auth-ready',init,{once:true});
})();
