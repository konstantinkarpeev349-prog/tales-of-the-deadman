const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '..', 'auth-client.js'), 'utf8');
const settle = () => new Promise(resolve => setTimeout(resolve, 20));

function mount({ banned = false, guest = false, fail = false, page = 'Account.html' } = {}) {
  const state = { banned, guest, fail, profileReads: 0, channels: 0, removed: 0, rpcCalls: 0, reloads: 0, scripts: [], poll: null };
  const classes = new Set();
  const classList = { add: (...names) => names.forEach(name => classes.add(name)), remove: (...names) => names.forEach(name => classes.delete(name)) };
  const children = new Map();
  const element = tag => ({
    tagName: tag, classList, hidden: false, textContent: '', innerHTML: '',
    querySelector(selector) { if (!children.has(selector)) children.set(selector, element('span')); return children.get(selector); },
    remove() { if (this.id === 'todm-ban-screen') state.panel = null; }
  });
  const document = {
    body: { classList, append(node) { if (node.id === 'todm-ban-screen') state.panel = node; } },
    head: { append(node) { if (node.src) state.scripts.push(node.src); } },
    createElement: element,
    querySelector(selector) { return selector === '#todm-ban-screen' ? state.panel || null : null; },
    visibilityState: 'visible'
  };
  let options;
  const client = {
    auth: {
      getSession: async () => ({ data: { session: state.guest ? null : { user: { id: 'u1', email: 'test@example.invalid' } } }, error: null }),
      getUser: async () => ({ data: { user: { id: 'u1' } }, error: null }),
      updateUser: async () => ({ data: { user: { id: 'u1' } }, error: null }),
      signOut: async () => ({ error: null }),
      onAuthStateChange(callback) { state.authChange = callback; }
    },
    from(table) {
      assert.ok(['account_access', 'profiles'].includes(table), table);
      if (table === 'profiles') state.profileReads++;
      return { select() { return this; }, eq() { return this; }, async maybeSingle() {
        if (table === 'account_access' && state.fail) return { data: null, error: Error('network') };
        return { data: table === 'account_access' ? { is_banned: state.banned } : { display_name: 'Reader' }, error: null };
      } };
    },
    channel() { state.channels++; return { on() { return this; }, subscribe() { return this; }, track: async () => ({}) }; },
    removeAllChannels: async () => { state.removed++; },
    rpc: async () => { state.rpcCalls++; return { data: {}, error: null }; }
  };
  const location = { pathname: '/' + page, href: 'https://todm.example/' + page, reload() { state.reloads++; } };
  const context = {
    window: { TODM_SUPABASE_CONFIG: { url: 'https://db.example', publishableKey: 'public' }, supabase: { createClient: (_url, _key, opts) => { options = opts; return client; } } },
    document, location, URL, console, Date, Error,
    fetch: async () => ({ ok: true }),
    CustomEvent: class { constructor(type, init) { this.type = type; this.detail = init?.detail; } },
    dispatchEvent() {}, addEventListener() {},
    setInterval(callback) { state.poll = callback; }, setTimeout() {}
  };
  vm.runInNewContext(source, context);
  return { state, auth: context.window.TODMAuth, client, options, classes, children };
}

test('active reader keeps the ordinary cabinet and starts Presence', async () => {
  const app = mount(); await settle();
  const account = await app.auth.getAccount();
  assert.equal(account.profile.display_name, 'Reader');
  assert.equal(app.state.channels, 1);
  assert.equal(app.state.panel, undefined);
  assert.equal(app.classes.has('todm-ban-pending'), false);
});

test('banned reader gets the ban screen without private profile or Presence', async () => {
  const app = mount({ banned: true }); await settle();
  await assert.rejects(app.auth.getAccount(), /Доступ к аккаунту ограничен/);
  assert.equal(app.state.profileReads, 0);
  assert.equal(app.state.channels, 0);
  assert.match(app.children.get('[data-ban-title]').textContent, /Доступ к аккаунту ограничен/);
  assert.equal(app.state.scripts.length, 0);
  await app.client.rpc('archive_activity_heartbeat');
  assert.equal(app.state.rpcCalls, 0);
  await assert.rejects(app.options.global.fetch('https://db.example/rest/v1/profiles'));
});

test('ban and unban during a session stop subscriptions and restore by reload', async () => {
  const app = mount(); await settle();
  app.state.banned = true; app.state.poll(); await settle();
  assert.equal(app.auth.banState, 'banned');
  assert.ok(app.state.removed > 0);
  app.state.banned = false; app.state.poll(); await settle();
  assert.equal(app.state.reloads, 1);
});

test('network error fails closed and retry can recover', async () => {
  const app = mount({ fail: true }); await settle();
  assert.equal(app.auth.banState, 'unknown');
  assert.match(app.children.get('[data-ban-title]').textContent, /Не удалось проверить доступ/);
  await assert.rejects(app.options.global.fetch('https://db.example/rest/v1/profiles'));
  app.state.fail = false; await app.auth.checkBan(true);
  assert.equal(app.state.reloads, 1);
});

test('public page remains visible for a banned session', async () => {
  const app = mount({ banned: true, page: 'index.html' }); await settle();
  assert.equal(app.classes.has('todm-ban-locked'), false);
  assert.equal(app.state.panel, undefined);
  assert.equal(app.state.channels, 0);
});

test('sign-out clears the ban state and stops subscriptions', async () => {
  const app = mount(); await settle();
  app.state.guest = true; app.state.authChange('SIGNED_OUT');
  assert.equal(app.auth.banState, 'guest');
  assert.ok(app.state.removed > 0);
});
