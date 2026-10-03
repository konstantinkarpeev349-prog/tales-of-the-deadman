const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'..');
const read=name=>fs.readFileSync(path.join(root,name),'utf8');

test('administration has only four primary destinations and five user tabs',()=>{
  const html=read('Admin.html'),js=read('admin-hub.js');
  assert.deepEqual([...html.matchAll(/data-section="([^"]+)"/g)].map(x=>x[1]),['overview','users','tickets','system']);
  assert.deepEqual([...js.matchAll(/\['(profile|progress|rewards|moderation|history)','[^']+'\]/g)].map(x=>x[1]),['profile','progress','rewards','moderation','history']);
});

test('sensitive actions use server RPCs and bounded OA input',()=>{
  const js=read('admin-hub.js'),sql=read('supabase/043_admin_hub.sql');
  assert.match(js,/admin_set_ban_reasoned/);
  assert.match(js,/archive_staff_adjust_points/);
  assert.match(js,/value="20"/);
  assert.match(js,/value="-20"/);
  assert.match(sql,/p_amount not in \(-20,20\)/);
  assert.match(sql,/p_banned is distinct from old_row\.is_banned/);
  assert.doesNotMatch(js,/\b(?:alert|confirm|prompt)\s*\(/);
  assert.doesNotMatch(js,/service_role|secret_key/i);
});

test('shop editor is explicit and not injected into reader account',()=>{
  assert.match(read('account-shop-prices.js'),/window\.TODMShopPrices=\{mount\}/);
  assert.doesNotMatch(read('profile.js'),/script\.src='account-shop-prices\.js'/);
  assert.match(read('admin-hub.js'),/account\.access\?\.is_author/);
});
