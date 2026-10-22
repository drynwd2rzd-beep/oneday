import { readFile } from 'node:fs/promises';
import { strict as assert } from 'node:assert';

const [html, css, app, worker, manifest] = await Promise.all(
  ['index.html', 'styles.css', 'app.js', 'service-worker.js', 'manifest.json'].map((file) =>
    readFile(file, 'utf8'),
  ),
);

assert.match(html, /<link rel="stylesheet" href="styles\.css"\s*\/>/);
assert.doesNotMatch(html, /<style\b/i, 'styles must live in the stylesheet');
assert.match(html, /<script src="app\.js"><\/script>/);
assert.match(worker, /'\.\/styles\.css'/, 'offline shell must cache the stylesheet');
assert.doesNotMatch(css, /<\/?style\b/i, 'stylesheet must not contain HTML tags');
assert.doesNotThrow(() => JSON.parse(manifest));
assert.ok(app.length > 1_000, 'application script should not be empty');

console.log('Smoke checks passed.');
