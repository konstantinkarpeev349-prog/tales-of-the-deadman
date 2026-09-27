const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const source = fs.readFileSync(path.join(__dirname, '..', 'tome-iii-gate.js'), 'utf8');

async function check(account) {
  const classes = new Set();
  const document = {
    body: { innerHTML: '' },
    documentElement: { classList: { add: value => classes.add(value) } }
  };
  const auth = { getAccount: async () => account };
  const context = {
    document,
    location: { pathname: '/Tome_III_Characters.html' },
    window: { TODMAuth: auth },
    TODMAuth: auth,
    addEventListener() {},
    setTimeout() {},
    console
  };
  vm.runInNewContext(source, context);
  await new Promise(resolve => setImmediate(resolve));
  return { html: document.body.innerHTML, visible: classes.has('tome-access-ready') };
}

(async () => {
  const guest = await check({ session: null });
  assert.match(guest.html, /Auth\.html\?next=Tome_III_Characters\.html/);

  for (const level of [0, 1, 2]) {
    const result = await check({ session: {}, access: { archive_level: level } });
    assert.match(result.html, /Доступ закрыт/);
  }

  for (const level of [3, 4, 5]) {
    const result = await check({ session: {}, access: { archive_level: level } });
    assert.equal(result.html, '');
    assert.equal(result.visible, true);
  }

  const staff = await check({ session: {}, access: { archive_level: 0, full_access: true } });
  assert.equal(staff.html, '');

  const banned = await check({ session: {}, access: { archive_level: 5, full_access: true, is_banned: true } });
  assert.match(banned.html, /Доступ закрыт/);

  const missingAccess = await check({ session: {}, profile: { archive_level: 5 }, access: null });
  assert.match(missingAccess.html, /Доступ закрыт/);

  console.log('tome-iii-gate: guest, levels 0–V, staff, banned and missing access passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
