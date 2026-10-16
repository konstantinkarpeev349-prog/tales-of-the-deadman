const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

const root = path.resolve(__dirname, '..');
const historical = fs.readFileSync(path.join(root, 'supabase', '037_archive_i_final_quiz.sql'), 'utf8');
const guard = fs.readFileSync(path.join(root, 'supabase', '045_archive_i_retry_guard.sql'), 'utf8');
const client = fs.readFileSync(path.join(root, 'archive-trial.js'), 'utf8');

assert.doesNotMatch(historical, /insert\s+into\s+public\.archive_quiz_questions/i);
assert.doesNotMatch(historical, /jsonb_build_array\s*\(/i);
assert.match(guard, /before\s+insert\s+on\s+public\.archive_quiz_attempts/i);
assert.match(guard, /max\(submitted_at\)\s*\+\s*interval\s*'24 hours'/i);
assert.match(guard, /'retry_at'/);
assert.match(guard, /v_started_at\s*<\s*now\(\)\s*-\s*interval\s*'2 hours'/i);
assert.doesNotMatch(client, /correct_option/);

console.log('archive-quiz-public-surface: no answer seed, server retry guard, no client key');
