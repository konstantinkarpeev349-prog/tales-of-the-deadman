const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');

const source = fs.readFileSync(require.resolve('../archive-trial.js'), 'utf8');
const element = () => ({ hidden: false, dataset: {}, innerHTML: '', addEventListener() {}, querySelector() { return null; } });

async function renderStatus(status) {
  const elements = [element(), element(), element(), element()];
  const trialStatus = elements[0];
  const auth = { client: { rpc: async name => {
    assert.equal(name, 'archive_i_quiz_status');
    return { data: status, error: null };
  } } };
  const sandbox = {
    window: { TODMAuth: auth }, TODMAuth: auth,
    document: { querySelector: () => elements.shift() },
    addEventListener() {},
    location: { reload() {} },
    FormData: class {}
  };
  vm.createContext(sandbox);
  vm.runInContext(source, sandbox);
  await new Promise(resolve => setImmediate(resolve));
  return trialStatus.innerHTML;
}

(async () => {
  const base = { authenticated: true, content_status: 'PUBLISHED', passed: true, best_score: 8 };
  const waiting = await renderStatus({ ...base, retry_at: '2026-10-11T12:00:00Z' });
  assert.match(waiting, /24 часа/);
  assert.doesNotMatch(waiting, /data-start/);
  const ready = await renderStatus({ ...base, retry_at: null });
  assert.match(ready, /data-start/);
  console.log('archive-trial-status: cooldown hides start action; ready state keeps it');
})().catch(error => { console.error(error); process.exitCode = 1; });
