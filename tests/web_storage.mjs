// 保存の置き場の確認。Web 書き出しを、窓なし・消音・使い捨てのプロフィールの Chrome で開き、CDP でキーとクリックを送る。
// 同じサイトの Godot のゲームは IndexedDB の /userfs(user:// の実体)を 1 つ共有するので、LuckLadder は localStorage に書く
// (save/save_store.gd の頭)。ゲームの中は覗かず、localStorage と /userfs の中身だけを見る。
//   1     v0.6.0 までの保存(/userfs)を引き継ぎ、localStorage へ移す
//   room  起動した後に別のゲームが /userfs に書いた物が、対戦の部屋を作って招待を作った後も残る(座標は 1280×720 の物)
//   2     同じく、ランで何手か保存した後も残る。読み込み直すと localStorage から読み、「つづきから」で続く
//   4     localStorage を読むと投げる・書くと投げる(保存を止めた・一杯)ブラウザでも止まらず、/userfs にも書かない
// node tests/web_storage.mjs [1] [room] [2] [4]   この順に回す。何も付けなければ全部。失敗が 1 件でもあれば終了コード 1
// 環境変数: LL_URL(確かめる URL。最後は /。公開中の版に当てる時など。既定は build/web を手元で配った物)、
//           LL_HTTP_PORT(既定 8774)、LL_CDP_PORT(既定 9774)、LL_CHROME(Chrome の exe)
import { spawn } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, rmdirSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { setTimeout as sleep } from 'node:timers/promises';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const WEB = path.join(ROOT, 'build', 'web');
const OUT = path.join(ROOT, 'build', 'web_shots');
const HTTP_PORT = Number(process.env.LL_HTTP_PORT || 8774);
const CDP_PORT = Number(process.env.LL_CDP_PORT || 9774);
const CHROME = process.env.LL_CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const KEY = 'luck-ladder/save'; // save/save_store.gd の WEB_KEY_PREFIX + save
const LEGACY = '/userfs/godot/app_userdata/LuckLadder/save.json'; // v0.6.0 までの user://save.json
const KEYS = {
	Enter: { key: 'Enter', code: 'Enter', windowsVirtualKeyCode: 13 },
	ArrowUp: { key: 'ArrowUp', code: 'ArrowUp', windowsVirtualKeyCode: 38 },
	ArrowDown: { key: 'ArrowDown', code: 'ArrowDown', windowsVirtualKeyCode: 40 },
};
// 対戦の部屋までのボタン(1280×720 の CSS の px。タイトルに「つづきから」が無い時の位置なので、room は 2 より先に回す)
const BTN = { versus: [827, 345], settings: [829, 537], host: [640, 160], invite: [950, 444] };

const picked = process.argv.slice(2);
const want = (name) => picked.length === 0 || picked.includes(name);
let failures = 0;
const expect = (ok, label) => {
	console.log(`${ok ? 'OK' : 'NG'}  ${label}`);
	if (!ok) failures++;
	return ok;
};

// /userfs の鍵を出す。旧版が書いた描画のキャッシュ(shader_cache の下)は数だけ
const show = (keys) => {
	const cache = keys.filter((k) => k.includes('/shader_cache')).length;
	return (keys.filter((k) => !k.includes('/shader_cache')).join(' ') || '(空)') + (cache ? ` + shader_cache の下 ${cache} 個` : '');
};

async function waitFor(fn, timeoutMs, everyMs = 250) {
	const end = Date.now() + timeoutMs;
	while (Date.now() < end) {
		const v = await fn();
		if (v) return v;
		await sleep(everyMs);
	}
	return null;
}

function serve() {
	if (process.env.LL_URL) return { url: process.env.LL_URL, stop: () => {} };
	if (!existsSync(path.join(WEB, 'index.html'))) throw new Error('build/web/index.html が無い(先に Web に書き出す)');
	const root = mkdtempSync(path.join(tmpdir(), 'll-site-'));
	symlinkSync(WEB, path.join(root, 'luck-ladder'), 'junction');
	const server = spawn('python', ['-m', 'http.server', String(HTTP_PORT), '--bind', '127.0.0.1', '--directory', root], { stdio: 'ignore' });
	// 止める時は、ジャンクションを消してから空のフォルダを消す(build/web は残す)
	return { url: `http://127.0.0.1:${HTTP_PORT}/luck-ladder/`, stop: () => { server.kill(); rmSync(path.join(root, 'luck-ladder')); rmdirSync(root); } };
}

async function openChrome() {
	mkdirSync(OUT, { recursive: true });
	const profile = mkdtempSync(path.join(tmpdir(), 'll-store-'));
	const proc = spawn(CHROME, ['--headless=new', '--mute-audio', `--remote-debugging-port=${CDP_PORT}`, `--user-data-dir=${profile}`,
		'--no-first-run', '--no-default-browser-check', '--disable-background-timer-throttling', '--disable-renderer-backgrounding',
		'--enable-unsafe-swiftshader', 'about:blank'], { stdio: 'ignore' });
	const target = await waitFor(async () => {
		try { return (await (await fetch(`http://127.0.0.1:${CDP_PORT}/json/list`)).json()).find((t) => t.type === 'page'); } catch { return null; }
	}, 60000);
	if (!target) { proc.kill(); throw new Error('ブラウザにつながらない'); }
	const ws = new WebSocket(target.webSocketDebuggerUrl);
	await new Promise((ok, ng) => { ws.onopen = ok; ws.onerror = ng; });
	let id = 0;
	const pending = new Map();
	const logs = [];
	ws.onmessage = (m) => {
		const msg = JSON.parse(m.data);
		if (msg.id && pending.has(msg.id)) {
			const { ok, ng } = pending.get(msg.id);
			pending.delete(msg.id);
			msg.error ? ng(new Error(msg.error.message)) : ok(msg.result);
		} else if (msg.method === 'Runtime.consoleAPICalled') logs.push({ level: msg.params.type, text: msg.params.args.map((a) => a.value ?? a.description).join(' ') });
		else if (msg.method === 'Runtime.exceptionThrown') logs.push({ level: 'exception', text: msg.params.exceptionDetails.exception?.description ?? msg.params.exceptionDetails.text });
	};
	const send = (method, params = {}) => new Promise((ok, ng) => {
		const i = ++id;
		pending.set(i, { ok, ng });
		ws.send(JSON.stringify({ id: i, method, params }));
	});
	for (const m of ['Runtime.enable', 'Page.enable']) await send(m);
	await send('Emulation.setFocusEmulationEnabled', { enabled: true });
	await send('Emulation.setDeviceMetricsOverride', { width: 1280, height: 720, deviceScaleFactor: 1, mobile: false });
	const evaluate = async (expression) => (await send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true })).result.value;
	const idb = (body) => evaluate(`(async () => {
		if (!(await indexedDB.databases()).some((d) => d.name === '/userfs')) return null;
		const db = await new Promise((ok, ng) => { const r = indexedDB.open('/userfs'); r.onsuccess = () => ok(r.result); r.onerror = () => ng(r.error); });
		try { ${body} } finally { db.close(); }
	})()`);
	const page = {
		logs, send, evaluate,
		// 開いて、Godot が起動する(コンソールに版の行が出る)まで待つ
		goto: async (url) => {
			const from = logs.length;
			await send('Page.navigate', { url });
			const ok = await waitFor(() => logs.slice(from).some((l) => String(l.text).startsWith('Godot Engine v')), 60000, 100);
			await sleep(2500); // タイトルが出て、押し間違いの受け止めが明けるまで
			return ok !== null;
		},
		saved: async () => JSON.parse(await evaluate(`localStorage.getItem('${KEY}')`) ?? 'null'),
		// /userfs の鍵の一覧(DB がまだ無ければ空)
		userfsKeys: async () => JSON.parse(await idb(`return JSON.stringify(await new Promise((ok) => {
			const r = db.transaction('FILE_DATA').objectStore('FILE_DATA').getAllKeys(); r.onsuccess = () => ok(r.result); r.onerror = () => ok([]); }));`) ?? '[]'),
		// /userfs のファイルの中身の文字(無ければ null)
		userfsText: async (p) => idb(`const e = await new Promise((ok) => { const r = db.transaction('FILE_DATA').objectStore('FILE_DATA').get(${JSON.stringify(p)});
			r.onsuccess = () => ok(r.result); r.onerror = () => ok(null); });
			return e && e.contents ? new TextDecoder().decode(e.contents) : null;`),
		// /userfs にファイルを入れる(別のゲームや旧版が書いた物の代わり)。IDBFS と同じ形で、入れる先のフォルダの項目も足す
		userfsPut: (files) => idb(`const tx = db.transaction('FILE_DATA', 'readwrite');
			const store = tx.objectStore('FILE_DATA');
			const now = new Date();
			for (const [p, text] of Object.entries(${JSON.stringify(files)})) {
				store.put({ timestamp: now, mode: 0o40777 }, p.slice(0, p.lastIndexOf('/')));
				store.put({ timestamp: now, mode: 0o100666, contents: new TextEncoder().encode(text) }, p);
			}
			await new Promise((ok, ng) => { tx.oncomplete = ok; tx.onerror = () => ng(tx.error); });
			return true;`),
		key: async (k) => {
			await send('Input.dispatchKeyEvent', { type: 'rawKeyDown', ...KEYS[k] });
			await send('Input.dispatchKeyEvent', { type: 'keyUp', ...KEYS[k] });
		},
		click: async ([x, y]) => {
			await send('Input.dispatchMouseEvent', { type: 'mouseMoved', x, y });
			await send('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', clickCount: 1 });
			await send('Input.dispatchMouseEvent', { type: 'mouseReleased', x, y, button: 'left', clickCount: 1 });
		},
		shot: async (label) => writeFileSync(path.join(OUT, `storage_${label}.png`), Buffer.from((await send('Page.captureScreenshot', { format: 'png' })).data, 'base64')),
		exceptions: () => logs.filter((l) => l.level === 'exception'),
		close: async () => {
			try { await send('Browser.close'); } catch { /* もう閉じた */ }
			ws.close();
			await Promise.race([new Promise((ok) => proc.once('exit', ok)), sleep(3000)]);
			proc.kill();
			rmSync(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 500 });
		},
	};
	return page;
}

// ランを始めて(Enter)、↑(HIGH)と ↓(LOW)を交互に 0.6 秒おきに押す(K や A では片方が押せない)。
// 保存に届いた手の列を返す(localStorage、無ければ旧版の /userfs)
async function playSome(page, presses = 8, start = true) {
	if (start) await page.key('Enter');
	await sleep(1200);
	for (let i = 0; i < presses; i++) {
		await page.key(i % 2 ? 'ArrowDown' : 'ArrowUp');
		await sleep(600);
	}
	await sleep(2000); // 旧版が /userfs を書き戻すなら、この間に起きる
	const fromLocal = await page.saved();
	const fromFile = JSON.parse((await page.userfsText(LEGACY)) ?? 'null');
	const save = fromLocal ?? fromFile;
	// ended: ライフが尽きてランが終わった(途中の保存が消え、結果が記録に入った)
	return { where: fromLocal ? 'localStorage' : fromFile ? '/userfs' : '(無い)', actions: save?.current_run?.actions ?? '', ended: save != null && save.current_run == null };
}

async function main(base) {
	const page = await openChrome();
	try {
		if (!expect(await page.goto(base), `Godot が起動した(${base})`)) return;
		await page.shot('title');
		console.log(`    最初の起動の後の /userfs: ${show(await page.userfsKeys())} / localStorage: ${(await page.saved()) ? 'あり' : '無し'}`);

		if (want('1')) {
			const old = { version: 1, tutorial_done: true, totals: { runs: 12, total_score: 3456 }, settings: { name: 'OLDSAVE1' } };
			await page.userfsPut({ [LEGACY]: JSON.stringify(old) });
			await page.evaluate(`localStorage.removeItem('${KEY}')`);
			await page.goto(base);
			const s = await waitFor(async () => { const v = await page.saved(); return v?.settings?.name === 'OLDSAVE1' ? v : null; }, 5000);
			expect(s !== null && s.totals.runs === 12 && s.totals.total_score === 3456 && s.tutorial_done === true,
				`(1) v0.6.0 までの保存(/userfs)を読み、localStorage に移す(localStorage: ${JSON.stringify(s?.totals ?? null)} 名前 ${s?.settings?.name})`);
			// 書けている時は、設定に「記録が残りません」(E-6)が出ない。目で見る用に撮る
			await page.click(BTN.settings);
			await sleep(1500);
			await page.shot('settings');
		}

		if (want('room')) {
			await page.goto(base);
			const OTHER2 = '/userfs/godot/app_userdata/OtherGame/later.json';
			await page.userfsPut({ [OTHER2]: '{}' });
			await page.click(BTN.versus);
			await sleep(1500);
			await page.shot('room_choose');
			await page.click(BTN.host);
			await sleep(1500);
			await page.click(BTN.invite);
			await sleep(4000);
			await page.shot('room_invite');
			const keys = await page.userfsKeys();
			expect(keys.includes(OTHER2), `(2) 対戦の部屋を作って招待を作っても、別のゲームが書いた /userfs の保存が残る(/userfs: ${show(keys)})`);
		}

		if (want('2')) {
			await page.goto(base);
			const OTHER = '/userfs/godot/app_userdata/OtherGame/save.json';
			await page.userfsPut({ [OTHER]: '{"other":true}' }); // このタブが起動した後に、別のゲームが書いた
			const r = await playSome(page);
			expect(r.actions.length > 0 || r.ended, `(2) ランを始めて手を打つと保存に届く(保存先 ${r.where}、手 "${r.actions}"${r.ended ? '・ランが終わった' : ''})`);
			const keys = await page.userfsKeys();
			expect(keys.includes(OTHER), `(2) 起動した後に別のゲームが書いた /userfs の保存が、こちらの保存の後も残る(/userfs: ${show(keys)})`);
			await page.shot('after_moves');
			// 次の起動は localStorage から読む(読めなければ /userfs の旧ファイルを読み、それで上書きするので中身が変わる)
			const before = await page.evaluate(`localStorage.getItem('${KEY}')`);
			await page.goto(base);
			expect(before !== null && await page.evaluate(`localStorage.getItem('${KEY}')`) === before, '(2) 読み込み直すと localStorage の保存を読む(旧ファイルで上書きしない)');
			const prev = JSON.parse(before ?? 'null')?.current_run?.actions;
			if (prev) {
				const r2 = await playSome(page, 4); // タイトルの最初のボタンは「つづきから」
				if (r2.ended) console.log(`--  (2) 「つづきから」の後にランが終わったので、手の列の続きは見られない`);
				else expect(r2.actions.length > prev.length && r2.actions.startsWith(prev), `(2) 「つづきから」で、保存した手の続きから遊べる("${prev}" → "${r2.actions}")`);
			}
		}

		if (want('4')) {
			// 保存を止めたブラウザ(localStorage を読むと投げる)と、一杯のブラウザ(setItem が投げる)。__llBlock が真の間だけ投げる
			const cases = [
				['読むと投げる', `const real = window.localStorage; Object.defineProperty(window, 'localStorage', { configurable: true,
					get() { if (window.__llBlock) throw new DOMException('blocked', 'SecurityError'); return real; } });`],
				['書くと投げる', `const set = Storage.prototype.setItem; Storage.prototype.setItem = function (k, v) {
					if (window.__llBlock) throw new DOMException('full', 'QuotaExceededError'); return set.call(this, k, v); };`],
			];
			for (const [label, src] of cases) {
				await page.evaluate(`localStorage.removeItem('${KEY}')`);
				const { identifier } = await page.send('Page.addScriptToEvaluateOnNewDocument', { source: `window.__llBlock = true; ${src}` });
				const from = page.logs.length;
				await page.goto(base);
				const OTHER3 = `/userfs/godot/app_userdata/OtherGame/${label === '読むと投げる' ? 'a' : 'b'}.json`;
				await page.userfsPut({ [OTHER3]: '{}' });
				await page.key('Enter'); // 投げている間にランを始める(途中の保存が書けない)
				await sleep(1500);
				const blocked = await page.saved().catch(() => null);
				await page.evaluate('window.__llBlock = false');
				const r = await playSome(page, 6, false);
				const caught = page.logs.slice(from).filter((l) => /localStorage|setItem/.test(String(l.text))).length;
				const exc = page.logs.slice(from).filter((l) => l.level === 'exception');
				expect(blocked === null && r.where === 'localStorage' && (r.actions.length > 0 || r.ended),
					`(4) ${label}間も止まらず、投げなくなった後の手は localStorage に届く(投げていた間の保存: ${blocked ? 'あり' : '無し'}、後の手 "${r.actions}"${r.ended ? '・ランが終わった' : ''}、橋が受け止めたエラーの行 ${caught})`);
				expect(exc.length === 0, `(4) ${label}: 受け止められない例外が無い${exc.length ? `(${exc.map((e) => e.text).join(' / ')})` : ''}`);
				const keys = await page.userfsKeys();
				expect(keys.includes(OTHER3), `(4) ${label}: /userfs に書かない(起動した後に入れた物が残る)`);
				await page.send('Page.removeScriptToEvaluateOnNewDocument', { identifier });
				await page.shot(`blocked_${label === '読むと投げる' ? 'get' : 'set'}`);
			}
		}
		const exc = page.exceptions();
		exc.forEach((l) => console.log(`    [exception] ${l.text}`));
	} finally { await page.close(); }
}

const site = serve();
try {
	await main(site.url);
} catch (e) {
	expect(false, `途中で止まった: ${e.stack ?? e}`);
} finally { site.stop(); }
console.log(failures === 0 ? 'ALL OK' : `${failures} 件 NG`);
process.exitCode = failures === 0 ? 0 : 1;
