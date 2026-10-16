const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const script = fs.readFileSync(path.join(__dirname, '..', 'archive-document.js'), 'utf8');

async function render(href, title = 'Связанный документ') {
  const root = {
    dataset: {
      slug: 'morgeus',
      hero: 'images/Morgeus.png',
      heroAlt: 'Моргеус',
      code: 'ARCHIVE-01'
    },
    innerHTML: ''
  };
  const record = { id: 'test-record', body: { title: 'Моргеус', related: { title, href } } };
  const client = {
    from(table) {
      if (table === 'content_reads') return { upsert: async () => ({ error: null }) };
      assert.equal(table, 'archive_content');
      return {
        select() { return this; },
        eq() { return this; },
        async maybeSingle() { return { data: record, error: null }; }
      };
    }
  };
  vm.runInNewContext(script, {
    document: { querySelector: () => root },
    location: { pathname: '/Archive_Morgeus.html' },
    TODMArchive: {
      account: async () => ({ session: {}, access: { archive_level: 1 }, user: { id: 'test-user' } }),
      can: () => true
    },
    TODMAuth: { client },
    URL,
    console,
    Date
  });
  await new Promise(resolve => setImmediate(resolve));
  return root.innerHTML;
}

test('existing internal archive navigation remains clickable', async () => {
  for (const name of ['Archive_Morgeus.html', 'Archive_Frauster_Maizervin.html']) {
    const html = await render(name);
    assert.ok(html.includes(`href="${name}"`), name);
  }
});

test('ordinary external HTTPS links remain clickable', async () => {
  const html = await render('https://example.org/archive?id=1#section');
  assert.match(html, /href="https:\/\/example\.org\/archive\?id=1#section"/);
  assert.match(html, /rel="noopener noreferrer"/);
});

test('dangerous and ambiguous links render as plain text', async () => {
  const rejected = [
    'javascript:alert(1)',
    'JaVaScRiPt:alert(1)',
    'data:text/html,alert(1)',
    'vbscript:msgbox(1)',
    '%6aavascript:alert(1)',
    '&#x6a;avascript:alert(1)',
    ' java\tscript:alert(1)',
    '\nhttps://example.org/',
    'https://example.org/%0a',
    'https://example.org\\@evil.test/',
    'https://user:pass@example.org/',
    'http://example.org/',
    '//example.org/',
    '../Archive_Morgeus.html',
    'Account.html',
    'Archive_Morgeus.html?next=javascript:alert(1)'
  ];
  for (const value of rejected) {
    const html = await render(value);
    const aside = html.match(/<aside class="archive-related">[\s\S]*?<\/aside>/)?.[0];
    assert.ok(aside, value);
    assert.doesNotMatch(aside, /<a\s/i, value);
    assert.match(aside, /<span>Связанный документ →<\/span>/, value);
  }
});

test('link label is escaped even when the URL is safe', async () => {
  const html = await render('Archive_Morgeus.html', '<img src=x onerror=alert(1)>');
  assert.doesNotMatch(html, /<img src=x/);
  assert.match(html, /&lt;img src=x onerror=alert\(1\)&gt;/);
});
