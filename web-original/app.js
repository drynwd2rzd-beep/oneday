const KEY = 'oneday_app_v3';
const colors = ['#287052', '#386b98', '#8057b8', '#c75c88', '#d77b48', '#68717a'];
const quotes = [
  '今天不需要改变人生，认真完成一件事就已经很好。',
  '慢一点没关系，方向没有丢就好。',
  '不要追求完美，把真正重要的事往前推一点。',
  '你不需要证明什么，持续行动就够了。',
  '今天的微小完成，会成为以后回头看的证据。',
  '生活不是冲刺，长期走下去比一时用力更重要。',
  '允许普通的一天，也认真过好普通的一天。',
];
const D = () => new Date(),
  pad = (n) => String(n).padStart(2, '0'),
  keyOf = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`,
  parseDate = (s) => {
    const [y, m, d] = String(s).split('-').map(Number);
    return new Date(y, m - 1, d);
  };
const uuid = () => crypto?.randomUUID?.() || String(Date.now() + Math.random());
const motivations = [
  { text: '完成今天该做的事，本身就是一种了不起的坚持。', author: 'OneDay' },
  { text: '不积跬步，无以至千里。', author: '荀子' },
  { text: '我们的最大弱点在于放弃，成功的必然之路就是不断地重来一次。', author: '托马斯·爱迪生' },
  { text: '你不需要跑得很快，只要一直向前。', author: '佚名' },
  { text: '做你认为正确的事，剩下的交给时间。', author: '佚名' },
];
const HOME_MODULE_DEFAULT = ['hero', 'tasks', 'note', 'progress', 'plans'];
const HOME_MODULE_META = {
  hero: { title: '问候与日期', desc: '日期、问候和每日一句' },
  tasks: { title: '今日事项', desc: '查看并完成今天的事项' },
  note: { title: '值得留下', desc: '快速记录今天真实的想法' },
  progress: { title: '今日完成情况', desc: '查看当天事项完成进度' },
  plans: { title: '我的计划', desc: '查看正在进行的长期计划' },
};
const blankSettings = () => ({
  theme: 'system',
  accent: '#287052',
  avatar: '',
  name: 'OneDay',
  signature: '记录生活，成为更好的自己。',
  quoteMode: 'daily',
  homeModules: [...HOME_MODULE_DEFAULT],
});
const blankState = () => ({ tasks: [], notes: {}, plans: [], settings: blankSettings() });
function normalize(raw) {
  const x = raw && typeof raw === 'object' ? raw : blankState();
  x.tasks = Array.isArray(x.tasks)
    ? x.tasks
        .filter(Boolean)
        .map((t) => ({
          id: String(t.id || uuid()),
          title: String(t.title ?? t.name ?? '').trim(),
          date: typeof t.date === 'string' ? t.date : keyOf(D()),
          created:
            typeof t.created === 'string'
              ? t.created
              : typeof t.date === 'string'
                ? t.date
                : keyOf(D()),
          repeat: t.repeat === 'daily' ? 'daily' : 'once',
          done: t.done && typeof t.done === 'object' ? t.done : {},
        }))
        .filter((t) => t.title)
    : [];
  x.notes = x.notes && typeof x.notes === 'object' && !Array.isArray(x.notes) ? x.notes : {};
  Object.keys(x.notes).forEach((k) => {
    const v = Array.isArray(x.notes[k]) ? x.notes[k] : [x.notes[k]];
    x.notes[k] = v
      .map((n) =>
        typeof n === 'string'
          ? { text: n, time: '', photos: [] }
          : {
              text: String(n?.text ?? n?.content ?? n?.value ?? '').trim(),
              time: String(n?.time ?? ''),
              photos: Array.isArray(n?.photos)
                ? n.photos
                    .filter((x) => typeof x === 'string' && x.startsWith('data:image/'))
                    .slice(0, 6)
                : [],
              tags: Array.isArray(n?.tags)
                ? n.tags
                    .filter((t) => typeof t === 'string')
                    .map((t) => t.trim().slice(0, 12))
                    .filter(Boolean)
                    .slice(0, 8)
                : [],
            },
      )
      .filter((n) => n.text || n.photos?.length);
    if (!x.notes[k].length) delete x.notes[k];
  });
  x.plans = Array.isArray(x.plans)
    ? x.plans
        .filter(Boolean)
        .map((p) => ({
          id: String(p.id || uuid()),
          title: String(p.title ?? p.name ?? '').trim(),
          desc: String(p.desc ?? p.description ?? ''),
          status: ['active', 'done', 'archived'].includes(p.status) ? p.status : 'active',
          created: typeof p.created === 'string' ? p.created : keyOf(D()),
        }))
        .filter((p) => p.title)
    : [];
  x.settings = x.settings && typeof x.settings === 'object' ? x.settings : {};
  x.settings.theme = ['light', 'dark', 'system'].includes(x.settings.theme)
    ? x.settings.theme
    : 'system';
  x.settings.accent = colors.includes(x.settings.accent) ? x.settings.accent : colors[0];
  x.settings.avatar = typeof x.settings.avatar === 'string' ? x.settings.avatar : '';
  x.settings.name =
    String(x.settings.name ?? 'OneDay')
      .trim()
      .slice(0, 20) || 'OneDay';
  x.settings.signature =
    String(x.settings.signature ?? '记录生活，成为更好的自己。')
      .trim()
      .slice(0, 80) || '记录生活，成为更好的自己。';
  x.settings.quoteMode = x.settings.quoteMode === 'static' ? 'static' : 'daily';
  const rawModules = Array.isArray(x.settings.homeModules)
    ? x.settings.homeModules
    : [...HOME_MODULE_DEFAULT];
  x.settings.homeModules = rawModules.filter(
    (id, i, a) => HOME_MODULE_META[id] && a.indexOf(id) === i,
  );
  return x;
}
const UI_SIZE_LABELS = { compact: '紧凑', standard: '标准', large: '大' };
function currentUiSize() {
  return UI_SIZE_LABELS[S.settings.uiSize] ? S.settings.uiSize : 'standard';
}
function applyUiSize() {
  const size = currentUiSize();
  S.settings.uiSize = size;
  document.documentElement.dataset.uiSize = size;
  const label = document.getElementById('uiSizeLabel');
  if (label) label.textContent = UI_SIZE_LABELS[size];
  document
    .querySelectorAll('[data-ui-size-choice]')
    .forEach((button) => button.classList.toggle('active', button.dataset.uiSizeChoice === size));
}
function openUiSize() {
  applyUiSize();
  openModal('uiSizeModal');
}
function saveUiSize() {
  const selectedSize = document.querySelector('[data-ui-size-choice].active')?.dataset.uiSizeChoice;
  if (!UI_SIZE_LABELS[selectedSize]) return;
  S.settings.uiSize = selectedSize;
  applyUiSize();
  save();
  closeModal('uiSizeModal');
  toast('界面大小已保存');
}
function sanitizeIds() {
  [...S.tasks, ...S.plans].forEach((item) => {
    const safe = String(item.id || '')
      .replace(/[^A-Za-z0-9_-]/g, '')
      .slice(0, 80);
    item.id = safe || uuid();
  });
}
let appDbPromise = null,
  appDbReady = false;
function openAppDb() {
  if (!('indexedDB' in window)) return Promise.reject(new Error('IndexedDB unavailable'));
  if (appDbPromise) return appDbPromise;
  appDbPromise = new Promise((resolve, reject) => {
    const request = indexedDB.open('oneday-app', 1);
    request.onupgradeneeded = () => {
      if (!request.result.objectStoreNames.contains('state'))
        request.result.createObjectStore('state');
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error || new Error('IndexedDB open failed'));
  });
  return appDbPromise;
}
function readDbState() {
  return openAppDb().then(
    (db) =>
      new Promise((resolve, reject) => {
        const request = db.transaction('state', 'readonly').objectStore('state').get('current');
        request.onsuccess = () => resolve(request.result || null);
        request.onerror = () => reject(request.error || new Error('IndexedDB read failed'));
      }),
  );
}
function writeDbState(value) {
  return openAppDb().then(
    (db) =>
      new Promise((resolve, reject) => {
        const request = db
          .transaction('state', 'readwrite')
          .objectStore('state')
          .put(value, 'current');
        request.onsuccess = () => resolve(true);
        request.onerror = () => reject(request.error || new Error('IndexedDB write failed'));
      }),
  );
}
function initStorage() {
  readDbState()
    .then((stored) => {
      if (stored && typeof stored === 'object') {
        S = normalize(stored);
        appDbReady = true;
        applyTheme();
        applyUiSize();
        renderToday();
        renderTasks();
        renderPlans();
        renderReview();
        renderMe();
      } else {
        writeDbState(S)
          .then(() => {
            appDbReady = true;
          })
          .catch((error) => console.warn('OneDay IndexedDB migration failed', error));
      }
    })
    .catch((error) => console.warn('OneDay IndexedDB unavailable', error));
}
function load() {
  try {
    return normalize(JSON.parse(localStorage.getItem(KEY) || 'null'));
  } catch {
    return blankState();
  }
}
let S = load(),
  selected = keyOf(D()),
  viewMonth = new Date(D().getFullYear(), D().getMonth(), 1),
  reviewMonth = new Date(viewMonth),
  selectedReviewDate = null,
  reviewTab = 'timeline',
  reviewOverviewMonth = new Date(viewMonth),
  taskFilter = 'all',
  taskTab = 'today',
  pendingTheme = S.settings.theme,
  pendingAccent = S.settings.accent;
function save() {
  sanitizeIds();
  S = normalize(S);
  writeDbState(S)
    .then(() => {
      appDbReady = true;
    })
    .catch((error) => console.warn('OneDay IndexedDB save failed', error));
  try {
    localStorage.setItem(KEY, JSON.stringify(S));
    return true;
  } catch (error) {
    console.warn('OneDay localStorage backup unavailable', error);
    return true;
  }
}
function esc(s) {
  return String(s ?? '').replace(
    /[&<>"']/g,
    (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c],
  );
}
function fmtDate(d) {
  return `${d.getFullYear()}年${d.getMonth() + 1}月${d.getDate()}日`;
}
function weekday(d) {
  return ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'][d.getDay()];
}
function toast(t) {
  const x = document.getElementById('toast');
  if (!x) return;
  x.textContent = t;
  x.classList.add('show');
  clearTimeout(toast.t);
  toast.t = setTimeout(() => x.classList.remove('show'), 1700);
}
function syncModalState() {
  const hasOpen = document.querySelector('.modal.open');
  document.body.classList.toggle('modal-open', !!hasOpen);
  document.body.style.overflow = hasOpen ? 'hidden' : '';
}
function openModal(id) {
  const modal = document.getElementById(id);
  if (!modal) return;
  modal.classList.add('open');
  modal.setAttribute('aria-hidden', 'false');
  syncModalState();
}
function closeModal(id) {
  const modal = document.getElementById(id);
  if (!modal) return;
  modal.classList.remove('open');
  modal.setAttribute('aria-hidden', 'true');
  syncModalState();
}
function applyTheme() {
  const mode = S.settings.theme;
  const dark =
    mode === 'dark' || (mode === 'system' && matchMedia('(prefers-color-scheme: dark)').matches);
  document.documentElement.dataset.theme = dark ? 'dark' : '';
  document.documentElement.style.setProperty('--green', S.settings.accent);
  document.documentElement.style.setProperty('--blue', S.settings.accent);
  const themeMeta = document.querySelector('meta[name="theme-color"]');
  if (themeMeta) themeMeta.setAttribute('content', dark ? '#151a20' : '#f5f4ef');
  document.documentElement.style.colorScheme = dark ? 'dark' : 'light';
}
function go(id) {
  document.querySelectorAll('.page').forEach((x) => x.classList.toggle('active', x.id === id));
  document
    .querySelectorAll('.nav button')
    .forEach((x) => x.classList.toggle('active', x.dataset.go === id));
  (
    ({
      today: renderToday,
      tasks: renderTasks,
      plans: renderPlans,
      review: renderReview,
      me: renderMe,
    })[id] || (() => {})
  )();
}
function installNavHitFix() {
  const nav = document.querySelector('.nav');
  if (!nav) return;
  // v0.6: native document scroll + native button hit testing.
  // No coordinate remapping or document-level touch interception.
  nav.addEventListener('click', (e) => {
    const b = e.target.closest('button[data-go]');
    if (!b || !nav.contains(b)) return;
    e.preventDefault();
    go(b.dataset.go);
  });
}
installNavHitFix();
document.querySelectorAll('#today .sectionHead .linkBtn').forEach((button) => {
  const text = button.textContent || '';
  button.type = 'button';
  button.onclick = () => go(text.includes('计划') ? 'plans' : 'tasks');
});
document.querySelectorAll('.modal').forEach((modal) => {
  modal.setAttribute('aria-hidden', modal.classList.contains('open') ? 'false' : 'true');
  modal.addEventListener('click', (e) => {
    if (e.target === modal) closeModal(modal.id);
  });
});
document.querySelectorAll('[data-ui-size-choice]').forEach(
  (button) =>
    (button.onclick = () => {
      const size = button.dataset.uiSizeChoice;
      if (!UI_SIZE_LABELS[size]) return;
      document.documentElement.dataset.uiSize = size;
      document
        .querySelectorAll('[data-ui-size-choice]')
        .forEach((option) => option.classList.toggle('active', option === button));
    }),
);
window.addEventListener('keydown', (e) => {
  if (e.key === 'Escape')
    document.querySelectorAll('.modal.open').forEach((modal) => closeModal(modal.id));
});
function greeting() {
  const h = D().getHours();
  return h < 11 ? '早上好。' : h < 18 ? '下午好。' : '晚上好。';
}
function taskForDate(t, k) {
  if (t.repeat === 'daily') return k >= String(t.created || t.date);
  return t.date === k;
}
function taskDone(t, k) {
  return !!t.done?.[k];
}
function setDone(t, k, v) {
  t.done = t.done || {};
  t.done[k] = v;
}
function completionCount(t) {
  return Object.values(t.done || {}).filter(Boolean).length;
}
function dayTaskStatus(k) {
  const list = S.tasks.filter((t) => taskForDate(t, k));
  if (!list.length) return 'none';
  const done = list.filter((t) => taskDone(t, k)).length;
  if (!done) return 'none';
  return done === list.length ? 'all' : 'partial';
}
function dayStatusDot(k) {
  const status = dayTaskStatus(k);
  if (status === 'all') return '<i class=\"dot\" title=\"当天事项已全部完成\"></i>';
  if (status === 'partial')
    return '<i class=\"dot partial\" style=\"background:#D7A43C\" title=\"当天事项部分完成\"></i>';
  return '';
}
function taskHTML(t, k) {
  const done = taskDone(t, k);
  return `<div class="task ${done ? 'done' : ''}"><button type="button" class="check ${done ? 'done' : ''}" data-id="${esc(t.id)}" aria-label="${done ? '取消完成' : '完成事项'}：${esc(t.title)}" aria-pressed="${done ? 'true' : 'false'}">${done ? '✓' : ''}</button><div style="flex:1"><div class="taskTitle">${esc(t.title)}</div><div class="taskMeta">${t.repeat === 'daily' ? '每天' : '单次'} · 已完成 ${completionCount(t)} 次</div></div><button type="button" class="dots" data-del="${esc(t.id)}" aria-label="删除事项：${esc(t.title)}">⋯</button></div>`;
}
function bindTaskActions(root, k) {
  root.querySelectorAll('.check').forEach((b) => (b.onclick = () => toggleTask(b.dataset.id, k)));
  root.querySelectorAll('[data-del]').forEach((b) => (b.onclick = () => deleteTask(b.dataset.del)));
}
function toggleTask(id, k) {
  const t = S.tasks.find((x) => x.id === id);
  if (!t) return;
  const before = S.tasks.filter((x) => taskForDate(x, k)).every((x) => taskDone(x, k));
  const completed = !taskDone(t, k);
  setDone(t, k, completed);
  save();
  renderToday();
  renderTasks();
  renderReview();
  toast(completed ? '已完成，进度已更新' : '已取消完成');
  const all = S.tasks.filter((x) => taskForDate(x, k));
  if (completed && !before && all.length && all.every((x) => taskDone(x, k))) showMotivation(k);
}
function deleteTask(id) {
  if (confirm('删除这个事项？')) {
    S.tasks = S.tasks.filter((t) => t.id !== id);
    save();
    renderTasks();
    renderToday();
    renderReview();
    toast('已删除');
  }
}
function renderToday() {
  const d = D(),
    k = keyOf(d);
  dateLabel.textContent = `${d.getMonth() + 1}月${d.getDate()}日 ${weekday(d)}`;
  document.getElementById('greeting').textContent = greeting();
  dailyQuote.textContent =
    S.settings.quoteMode === 'static'
      ? quotes[0]
      : quotes[Math.floor(d.getTime() / 86400000) % quotes.length];
  const list = S.tasks.filter((t) => taskForDate(t, k)),
    todo = list.filter((t) => !taskDone(t, k)),
    done = list.filter((t) => taskDone(t, k));
  todayTasks.innerHTML = todo.length
    ? todo.map((t) => taskHTML(t, k)).join('')
    : `<div class="empty">${done.length ? '今天的事项已经完成了。' : '今天没有待办事项。'}</div>`;
  bindTaskActions(todayTasks, k);
  const total = list.length,
    p = total ? Math.round((done.length / total) * 100) : 0;
  progressNum.textContent = p + '%';
  progressBar.style.width = p + '%';
  progressDetail.textContent = total ? `${done.length}/${total} 已完成` : '从一件小事开始';
  const activePlans = S.plans.filter((p) => p.status === 'active').slice(0, 3);
  const hp = document.getElementById('homePlans');
  if (hp)
    hp.innerHTML = activePlans.length
      ? activePlans
          .map(
            (p) =>
              `<div class="homePlanItem"><div class="homePlanTitle">${esc(p.title)}</div><div class="homePlanDesc">${esc(p.desc || '正在前进。')}</div></div>`,
          )
          .join('')
      : '<div class="card empty">还没有进行中的计划。</div>';
  renderHomeModules();
}
function renderHomeModules() {
  const order = S.settings.homeModules || HOME_MODULE_DEFAULT;
  const page = document.getElementById('today');
  const top = page.querySelector('.top');
  const nodes = Object.fromEntries(
    [...page.querySelectorAll('[data-home-module]')].map((n) => [n.dataset.homeModule, n]),
  );
  order
    .slice()
    .reverse()
    .forEach((id) => {
      const n = nodes[id];
      if (n) {
        n.classList.remove('hidden');
        page.insertBefore(n, top.nextSibling);
      }
    });
  Object.entries(nodes).forEach(([id, n]) => n.classList.toggle('hidden', !order.includes(id)));
}
function openHomeCustomize() {
  renderHomeCustomize();
  openModal('homeCustomizeModal');
}
function renderHomeCustomize() {
  const host = document.getElementById('homeCustomizeList');
  const order = S.settings.homeModules || [...HOME_MODULE_DEFAULT];
  host.innerHTML =
    order
      .map((id, i) => {
        const m = HOME_MODULE_META[id];
        return `<div class="customizeItem"><button class="moduleSwitch on" data-toggle-module="${id}">✓</button><div><div class="moduleTitle">${m.title}</div><div class="moduleDesc">${m.desc}</div></div><div class="moduleMove"><button data-move-module="${id}" data-dir="-1" ${i === 0 ? 'disabled' : ''}>↑</button><button data-move-module="${id}" data-dir="1" ${i === order.length - 1 ? 'disabled' : ''}>↓</button></div></div>`;
      })
      .join('') +
    HOME_MODULE_DEFAULT.filter((id) => !order.includes(id))
      .map((id) => {
        const m = HOME_MODULE_META[id];
        return `<div class="customizeItem"><button class="moduleSwitch" data-toggle-module="${id}">✓</button><div><div class="moduleTitle">${m.title}</div><div class="moduleDesc">${m.desc}</div></div><div></div></div>`;
      })
      .join('');
  host
    .querySelectorAll('[data-toggle-module]')
    .forEach((b) => (b.onclick = () => toggleHomeModule(b.dataset.toggleModule)));
  host
    .querySelectorAll('[data-move-module]')
    .forEach(
      (b) => (b.onclick = () => moveHomeModule(b.dataset.moveModule, Number(b.dataset.dir))),
    );
}
function toggleHomeModule(id) {
  let order = [...(S.settings.homeModules || HOME_MODULE_DEFAULT)];
  order = order.includes(id) ? order.filter((x) => x !== id) : [...order, id];
  S.settings.homeModules = order;
  save();
  renderHomeModules();
  renderHomeCustomize();
}
function moveHomeModule(id, dir) {
  const order = [...(S.settings.homeModules || HOME_MODULE_DEFAULT)],
    i = order.indexOf(id),
    j = i + dir;
  if (i < 0 || j < 0 || j >= order.length) return;
  [order[i], order[j]] = [order[j], order[i]];
  S.settings.homeModules = order;
  save();
  renderHomeModules();
  renderHomeCustomize();
}
function resetHomeModules() {
  S.settings.homeModules = [...HOME_MODULE_DEFAULT];
  save();
  renderHomeModules();
  renderHomeCustomize();
  toast('已恢复首页默认布局');
}
function openNote() {
  noteInput.value = '';
  openModal('noteModal');
}
function saveNote() {
  const text = noteInput.value.trim();
  if (!text) return toast('写一点真实的想法吧');
  const k = keyOf(D());
  S.notes[k] = Array.isArray(S.notes[k]) ? S.notes[k] : [];
  S.notes[k].push({
    text,
    time: new Date().toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' }),
  });
  save();
  closeModal('noteModal');
  renderToday();
  renderReview();
  toast('已经留下');
}
function openTask() {
  taskInput.value = '';
  taskRepeat.value = 'once';
  openModal('taskModal');
}
function saveTask() {
  const title = taskInput.value.trim();
  if (!title) return toast('先写下要做什么');
  S.tasks.push({
    id: uuid(),
    title,
    date: selected,
    created: selected,
    repeat: taskRepeat.value,
    done: {},
  });
  save();
  closeModal('taskModal');
  renderTasks();
  renderToday();
  toast('已添加');
}
function setTaskTab(tab) {
  taskTab = tab;
  document
    .querySelectorAll('[data-task-tab]')
    .forEach((b) => b.classList.toggle('active', b.dataset.taskTab === tab));
  document
    .querySelectorAll('.taskPanel')
    .forEach((p) =>
      p.classList.toggle('active', p.id === 'taskPanel' + tab[0].toUpperCase() + tab.slice(1)),
    );
}
document
  .querySelectorAll('[data-task-tab]')
  .forEach((b) => (b.onclick = () => setTaskTab(b.dataset.taskTab)));
document.querySelectorAll('[data-filter]').forEach(
  (b) =>
    (b.onclick = () => {
      taskFilter = b.dataset.filter;
      document
        .querySelectorAll('[data-filter]')
        .forEach((x) => x.classList.toggle('active', x.dataset.filter === taskFilter));
      renderTasks();
    }),
);
function renderTasks() {
  const all = S.tasks.filter((t) => taskForDate(t, selected)),
    done = all.filter((t) => taskDone(t, selected)),
    active = all.filter((t) => !taskDone(t, selected));
  fAll.textContent = all.length;
  fActive.textContent = active.length;
  fDone.textContent = done.length;
  let show = taskFilter === 'all' ? all : taskFilter === 'active' ? active : done;
  selectedDateTitle.textContent = selected === keyOf(D()) ? '今天' : fmtDate(parseDate(selected));
  selectedTasks.innerHTML = show.length
    ? show.map((t) => taskHTML(t, selected)).join('')
    : '<div class="empty">这里还没有事项。</div>';
  bindTaskActions(selectedTasks, selected);
  renderCalendar();
  setTaskTab(taskTab);
}
function changeMonth(n) {
  viewMonth.setMonth(viewMonth.getMonth() + n);
  renderCalendar();
}
function selectDate(k) {
  selected = k;
  viewMonth = new Date(parseDate(k).getFullYear(), parseDate(k).getMonth(), 1);
  renderTasks();
  setTaskTab('today');
}
function renderCalendar() {
  const y = viewMonth.getFullYear(),
    m = viewMonth.getMonth();
  monthLabel.textContent = `${y}年${m + 1}月`;
  let h = '';
  const first = new Date(y, m, 1).getDay(),
    days = new Date(y, m + 1, 0).getDate();
  for (let i = 0; i < first; i++) h += '<div></div>';
  for (let day = 1; day <= days; day++) {
    const k = keyOf(new Date(y, m, day));
    h += `<button class="day ${k === selected ? 'selected' : ''}" data-date="${k}">${day}${dayStatusDot(k)}</button>`;
  }
  calendarDays.innerHTML = h;
  calendarDays.querySelectorAll('[data-date]').forEach(
    (b) =>
      (b.onclick = () => {
        selected = b.dataset.date;
        renderCalendar();
        renderTasks();
        setTaskTab('calendar');
      }),
  );
  calendarDateTitle.textContent = fmtDate(parseDate(selected)) + ' ' + weekday(parseDate(selected));
  const list = S.tasks.filter((t) => taskForDate(t, selected));
  calendarTasks.innerHTML = list.length
    ? list.map((t) => taskHTML(t, selected)).join('')
    : '<div class="empty">这一天没有事项。</div>';
  bindTaskActions(calendarTasks, selected);
}
let editingPlanId = null;
function openPlan() {
  editingPlanId = null;
  planTitle.value = '';
  planDesc.value = '';
  planModalTitle.textContent = '新的计划';
  openModal('planModal');
}
function editPlan(id) {
  const p = S.plans.find((x) => x.id === id);
  if (!p) return;
  editingPlanId = id;
  planTitle.value = p.title || '';
  planDesc.value = p.desc || '';
  planModalTitle.textContent = '编辑计划';
  openModal('planModal');
}
function savePlan() {
  const title = planTitle.value.trim();
  if (!title) return toast('计划需要一个名字');
  const desc = planDesc.value.trim();
  if (editingPlanId) {
    const p = S.plans.find((x) => x.id === editingPlanId);
    if (!p) return;
    p.title = title;
    p.desc = desc;
    save();
    editingPlanId = null;
    closeModal('planModal');
    renderPlans();
    renderToday();
    toast('计划已更新');
    return;
  }
  S.plans.push({ id: uuid(), title, desc, status: 'active', created: keyOf(D()) });
  save();
  closeModal('planModal');
  renderPlans();
  toast('已添加计划');
}
function planCard(p) {
  const status = p.status === 'active' ? '进行中' : p.status === 'done' ? '已完成' : '已归档';
  return `<div class="card planCard"><div class="small">${status}</div><h2>${esc(p.title)}</h2><div class="empty">${esc(p.desc || '没有额外说明。')}</div><div class="planStatus">${p.status === 'active' ? '正在前进' : p.status === 'done' ? '已经完成' : '暂时归档'}</div><div class="planActions"><button class="secondary" onclick="editPlan('${p.id}')">编辑</button>${p.status === 'active' ? `<button class="secondary" onclick="planStatus('${p.id}','done')">完成</button><button class="secondary" onclick="planStatus('${p.id}','archived')">归档</button>` : `<button class="secondary" onclick="planStatus('${p.id}','active')">重新进行</button>`}<button class="secondary danger" onclick="deletePlan('${p.id}')">删除</button></div></div>`;
}
function renderPlans() {
  const a = S.plans.filter((p) => p.status === 'active'),
    d = S.plans.filter((p) => p.status === 'done'),
    r = S.plans.filter((p) => p.status === 'archived');
  plansList.innerHTML =
    (a.length
      ? a.map(planCard).join('')
      : '<div class="card empty">还没有进行中的计划。先写下真正重要的方向。</div>') +
    collapseSection('donePlans', '已完成', d) +
    collapseSection('archivedPlans', '已归档', r);
}
function collapseSection(id, title, items) {
  return `<div class="collapseBox"><button class="collapseHead" onclick="toggleCollapse('${id}')"><span>${title}</span><span>${items.length} 个 ›</span></button><div class="collapseBody" id="${id}">${items.map(planCard).join('')}</div></div>`;
}
function toggleCollapse(id) {
  document.getElementById(id)?.classList.toggle('open');
}
function planStatus(id, status) {
  const p = S.plans.find((x) => x.id === id);
  if (!p) return;
  p.status = status;
  save();
  renderPlans();
  toast('已更新计划状态');
}
function deletePlan(id) {
  if (confirm('删除这个计划？')) {
    S.plans = S.plans.filter((x) => x.id !== id);
    save();
    renderPlans();
    toast('已删除');
  }
}
let pendingQuickPhotos = [];
function handleQuickPhotos(files) {
  const list = [...(files || [])]
    .filter((f) => f.type?.startsWith('image/'))
    .slice(0, 6 - pendingQuickPhotos.length);
  if (!list.length) return;
  if (list.length < (files || []).length && pendingQuickPhotos.length >= 6)
    toast('最多添加 6 张照片');
  Promise.all(list.map(compressImage))
    .then((arr) => {
      pendingQuickPhotos.push(...arr.filter(Boolean));
      renderQuickPhotoPreview();
    })
    .catch(() => toast('照片读取失败'));
}
function compressImage(file) {
  return new Promise((resolve, reject) => {
    const r = new FileReader();
    r.onload = () => {
      const img = new Image();
      img.onload = () => {
        let w = img.naturalWidth,
          h = img.naturalHeight,
          max = 1280;
        if (Math.max(w, h) > max) {
          const q = max / Math.max(w, h);
          w = Math.round(w * q);
          h = Math.round(h * q);
        }
        const c = document.createElement('canvas');
        c.width = w;
        c.height = h;
        const ctx = c.getContext('2d');
        ctx.drawImage(img, 0, 0, w, h);
        resolve(c.toDataURL('image/jpeg', 0.82));
      };
      img.onerror = reject;
      img.src = r.result;
    };
    r.onerror = reject;
    r.readAsDataURL(file);
  });
}
function renderQuickPhotoPreview() {
  const box = document.getElementById('quickPhotoPreview');
  if (!box) return;
  box.innerHTML = pendingQuickPhotos
    .map(
      (src, i) =>
        `<div class="quickPhotoItem"><img src="${src}" alt="照片 ${i + 1}"><button class="quickPhotoRemove" type="button" onclick="removeQuickPhoto(${i})">×</button></div>`,
    )
    .join('');
}
function removeQuickPhoto(i) {
  pendingQuickPhotos.splice(i, 1);
  renderQuickPhotoPreview();
}
function saveQuickNote() {
  const input = document.getElementById('quickNoteInput'),
    text = input?.value.trim() || '';
  if (!text && !pendingQuickPhotos.length) return toast('写一点内容，或者留下一张照片');
  const k = keyOf(D()),
    time = `${pad(D().getHours())}:${pad(D().getMinutes())}`;
  S.notes[k] = S.notes[k] || [];
  S.notes[k].push({ text, time, photos: [...pendingQuickPhotos] });
  save();
  input.value = '';
  pendingQuickPhotos = [];
  const photoInput = document.getElementById('quickPhotoInput');
  if (photoInput) photoInput.value = '';
  renderQuickPhotoPreview();
  renderReview();
  renderToday();
  toast('已经留下来了');
}
function recordDates() {
  // 回顾日期只来源于文字记录；事项完成状态不参与回顾日历或时间线。
  return Object.keys(S.notes)
    .filter((k) => Array.isArray(S.notes[k]) && S.notes[k].length > 0)
    .sort((a, b) => b.localeCompare(a));
}
function reviewTasks(k) {
  return S.tasks.filter((t) => taskForDate(t, k));
}
function reviewMarkers(k) {
  // 右上角标记只代表“值得留下”的文字记录，不参与事项完成状态。
  // 有记录显示一个实心点；没有记录不显示点，避免与任务完成混淆。
  const hasNote = Array.isArray(S.notes[k]) && S.notes[k].length > 0;
  return hasNote ? '<span class="reviewMarker done note" title="有文字记录"></span>' : '';
}
function monthKey(k) {
  const d = parseDate(k);
  return `${d.getFullYear()}年${d.getMonth() + 1}月`;
}
function reviewExcerpt(notes) {
  return notes?.length
    ? notes[0].text
      ? esc(notes[0].text).replace(/\n+/g, ' ')
      : notes[0].photos?.length
        ? '留下了照片'
        : ''
    : '';
}
function setReviewTab(tab) {
  reviewTab = tab;
  selectedReviewDate = null;
  renderReview();
}
function changeOverviewMonth(n) {
  reviewOverviewMonth = new Date(
    reviewOverviewMonth.getFullYear(),
    reviewOverviewMonth.getMonth() + n,
    1,
  );
  renderReview();
}
function monthBounds(d) {
  return {
    start: keyOf(new Date(d.getFullYear(), d.getMonth(), 1)),
    end: keyOf(new Date(d.getFullYear(), d.getMonth() + 1, 0)),
  };
}
function monthlyOverview(month) {
  const { start, end } = monthBounds(month);
  const items = S.tasks
    .map((t) => {
      let count = 0;
      Object.entries(t.done || {}).forEach(([k, v]) => {
        if (v && k >= start && k <= end) count++;
      });
      return { title: t.title, count };
    })
    .filter((x) => x.count > 0)
    .sort((a, b) => b.count - a.count || a.title.localeCompare(b.title, 'zh-CN'));
  const total = items.reduce((n, x) => n + x.count, 0);
  const noteDays = Object.entries(S.notes).filter(
    ([k, v]) => k >= start && k <= end && v?.length,
  ).length;
  const active = new Set();
  Object.entries(S.notes).forEach(([k, v]) => {
    if (k >= start && k <= end && v?.length) active.add(k);
  });
  S.tasks.forEach((t) =>
    Object.entries(t.done || {}).forEach(([k, v]) => {
      if (v && k >= start && k <= end) active.add(k);
    }),
  );
  return { items, total, noteDays, activeDays: active.size };
}
function renderReviewOverview() {
  const data = monthlyOverview(reviewOverviewMonth),
    label = `${reviewOverviewMonth.getFullYear()}年${reviewOverviewMonth.getMonth() + 1}月`,
    max = Math.max(1, ...data.items.map((x) => x.count));
  reviewList.innerHTML = `<div class="overviewMonth"><button aria-label="上个月" onclick="changeOverviewMonth(-1)">‹</button><strong>${label}</strong><button aria-label="下个月" onclick="changeOverviewMonth(1)">›</button></div><section class="overviewHero"><div class="overviewHeroLabel">本月完成事项</div><div class="overviewHeroRow"><div class="overviewHeroNum">${data.total}<span>次</span></div><div class="overviewHeroSub">每一次完成，都是<br>真实发生过的一天。</div></div></section><section class="overviewList"><div class="overviewListHead"><span>各事项完成次数</span><span class="small">${data.items.length ? `${data.items.length} 个事项` : '暂无数据'}</span></div>${data.items.length ? data.items.map((x) => `<div class="overviewItem"><div class="overviewItemName">${esc(x.title)}</div><div class="overviewItemCount">${x.count} 次</div><div class="overviewBar"><i style="width:${Math.max(8, Math.round((x.count / max) * 100))}%"></i></div></div>`).join('') : '<div class="overviewEmpty">这个月还没有完成记录。<br>完成一次事项后，这里会自动出现。</div>'}</section><section class="overviewStats"><div class="overviewStat"><span>完成次数</span><strong>${data.total}</strong></div><div class="overviewStat"><span>有文字记录</span><strong>${data.noteDays} 天</strong></div><div class="overviewStat"><span>留下文字</span><strong>${data.noteDays} 天</strong></div></section>`;
}
function renderReviewTimeline() {
  const list = selectedReviewDate ? [selectedReviewDate] : recordDates();
  if (selectedReviewDate) {
    const k = selectedReviewDate,
      d = parseDate(k),
      notes = S.notes[k] || [],
      tasks = reviewTasks(k);
    reviewList.innerHTML = `<div class="reviewDayHero"><div class="reviewDayLabel">${fmtDate(d)} · ${weekday(d)}</div><div class="reviewDayTitle">那一天</div><div class="reviewDaySub">回到这一天，看看留下了什么。</div></div>${notes.length ? `<section class="reviewFocusCard">${notes.map((n, i) => `<div class="reviewSwipeRow" data-review-swipe data-review-date="${k}" data-review-index="${i}"><div class="reviewSwipeDelete">删除</div><div class="reviewFocusEntry"><div class="reviewEntryHead"><div class="reviewEntryMeta">${n.time ? esc(n.time) : `记录 ${i + 1}`}</div></div>${n.text ? `<div class="reviewText">${esc(n.text)}</div>` : ''}${n.photos?.length ? `<div class="reviewPhotos">${n.photos.map((src, j) => `<img class="reviewPhoto" src="${src}" alt="记录照片 ${j + 1}" loading="lazy" onclick="openPhotoPreview(this.src)">`).join('')}</div>` : ''}</div></div>`).join('')}</section>` : ''}<section class="reviewTasksCard"><div class="reviewTasksHead">那一天的事项</div>${tasks.length ? tasks.map((t) => `<div class="reviewTaskRow"><span class="reviewCheck ${taskDone(t, k) ? 'done' : ''}">${taskDone(t, k) ? '✓' : ''}</span><span>${esc(t.title)}</span></div>`).join('') : '<div class="reviewQuiet">这一天没有安排事项。</div>'}</section><div class="reviewDayActions">${notes.length ? `<button class="secondary danger reviewDeleteAllBtn" type="button" onclick="deleteReviewDay('${k}')">删除全部记录</button>` : ''}<button class="reviewTimelineBtn" type="button" onclick="clearReviewDate()">查看时间线 <span>→</span></button></div>`;
    bindReviewEntrySwipe(reviewList);
    return;
  }
  if (!list.length) {
    reviewList.innerHTML =
      '<div class="card empty">开始留下文字记录后，这里会慢慢长出属于你的时间线。</div>';
    return;
  }
  let lastMonth = '';
  reviewList.innerHTML = list
    .map((k) => {
      const d = parseDate(k),
        notes = S.notes[k] || [],
        mk = monthKey(k),
        month = mk !== lastMonth ? `<div class="reviewMonthDivider">${mk}</div>` : '';
      lastMonth = mk;
      const done = reviewTasks(k).filter((t) => taskDone(t, k)).length,
        hasNote = notes.length > 0;
      return `${month}<button class="timelineCard" data-review-date="${k}"><div class="timelineMain"><div class="timelineDate"><strong>${d.getMonth() + 1}月${d.getDate()}日</strong><span>${weekday(d)}</span></div><div class="timelineExcerpt">${reviewExcerpt(notes)}</div><div class="timelineMeta">${hasNote ? '<span>有记录</span>' : ''}${done ? `<span>完成了 ${done} 件事项</span>` : ''}</div></div><div class="timelineSide"><div class="reviewMarkers">${reviewMarkers(k)}</div><span class="timelineArrow">›</span></div></button>`;
    })
    .join('');
  reviewList.querySelectorAll('[data-review-date]').forEach(
    (b) =>
      (b.onclick = () => {
        selectedReviewDate = b.dataset.reviewDate;
        renderReview();
        window.scrollTo?.({ top: 0, behavior: 'smooth' });
      }),
  );
}
function renderReview() {
  document
    .getElementById('reviewTabTimeline')
    ?.classList.toggle('active', reviewTab === 'timeline');
  document
    .getElementById('reviewTabOverview')
    ?.classList.toggle('active', reviewTab === 'overview');
  if (reviewTab === 'overview') {
    renderReviewOverview();
    return;
  }
  renderReviewTimeline();
}
function bindReviewEntrySwipe(root) {
  root.querySelectorAll('[data-review-swipe]').forEach((row) => {
    const card = row.querySelector('.reviewFocusEntry'),
      action = row.querySelector('.reviewSwipeDelete');
    if (!card || !action) return;
    let startX = 0,
      startY = 0,
      current = 0,
      dragging = false,
      horizontal = false,
      open = false;
    const max = 72;
    const setX = (x, animate = false) => {
      row.classList.toggle('swiped', x < 0);
      card.style.transition = animate ? 'transform .2s ease' : '';
      card.style.transform = `translateX(${x}px)`;
      current = x;
    };
    const close = () => {
      open = false;
      setX(0, true);
    };
    action.setAttribute('role', 'button');
    action.setAttribute('tabindex', '0');
    action.setAttribute('aria-label', '删除这条记录');
    card.addEventListener(
      'touchstart',
      (e) => {
        startX = e.touches[0].clientX;
        startY = e.touches[0].clientY;
        dragging = true;
        horizontal = false;
        card.style.transition = 'none';
      },
      { passive: true },
    );
    card.addEventListener(
      'touchmove',
      (e) => {
        if (!dragging) return;
        const dx = e.touches[0].clientX - startX;
        const dy = e.touches[0].clientY - startY;
        if (!horizontal) {
          if (Math.abs(dy) > Math.abs(dx) + 6) {
            dragging = false;
            return;
          }
          if (Math.abs(dx) < 8) return;
          horizontal = true;
        }
        e.preventDefault();
        const x = Math.max(-max, Math.min(0, (open ? -max : 0) + dx));
        setX(x, false);
      },
      { passive: false },
    );
    card.addEventListener('touchend', () => {
      if (!dragging) return;
      dragging = false;
      if (!horizontal) return;
      open = current < -34;
      setX(open ? -max : 0, true);
    });
    card.addEventListener('touchcancel', () => {
      dragging = false;
      close();
    });
    action.onclick = () =>
      deleteReviewEntry(row.dataset.reviewDate, Number(row.dataset.reviewIndex));
    action.onkeydown = (e) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        action.click();
      }
    };
    row.addEventListener('click', (e) => {
      if (open && !action.contains(e.target)) {
        e.preventDefault();
        close();
      }
    });
  });
}
function deleteReviewEntry(k, i) {
  const notes = S.notes[k];
  if (!Array.isArray(notes) || !notes[i]) return;
  if (!confirm('删除这条记录？')) return;
  notes.splice(i, 1);
  if (!notes.length) delete S.notes[k];
  save();
  if (!S.notes[k]?.length) selectedReviewDate = null;
  renderReview();
  renderToday();
  toast('已删除这条记录');
}
function deleteReviewDay(k) {
  const d = parseDate(k);
  if (
    !confirm(
      `删除 ${fmtDate(d)} 的全部记录？\n\n这只会删除当天留下的文字和照片，不会影响事项完成状态。`,
    )
  )
    return;
  delete S.notes[k];
  save();
  if (selectedReviewDate === k) selectedReviewDate = null;
  renderReview();
  renderToday();
  toast('已删除全部记录');
}
function clearReviewDate() {
  selectedReviewDate = null;
  reviewTab = 'timeline';
  renderReview();
}
function openReviewCalendar() {
  reviewMonth = selectedReviewDate
    ? new Date(
        parseDate(selectedReviewDate).getFullYear(),
        parseDate(selectedReviewDate).getMonth(),
        1,
      )
    : new Date(D().getFullYear(), D().getMonth(), 1);
  renderReviewCalendar();
  openModal('reviewCalModal');
}
function changeReviewMonth(n) {
  reviewMonth.setMonth(reviewMonth.getMonth() + n);
  renderReviewCalendar();
}
function renderReviewCalendar() {
  const y = reviewMonth.getFullYear(),
    m = reviewMonth.getMonth();
  reviewMonthLabel.textContent = `${y}年${m + 1}月`;
  let h = '';
  const first = new Date(y, m, 1).getDay(),
    days = new Date(y, m + 1, 0).getDate();
  for (let i = 0; i < first; i++) h += '<div></div>';
  for (let day = 1; day <= days; day++) {
    const k = keyOf(new Date(y, m, day)),
      hasNote = recordDates().includes(k);
    // 回顾日历只显示文字/照片记录的绿色点，绝不复用事项的完成状态点。
    h += `<button class="day ${k === selectedReviewDate ? 'selected' : ''}" data-rdate="${k}">${day}${hasNote ? '<i class=\"dot note\" title=\"有记录\"></i>' : ''}</button>`;
  }
  reviewCalendarDays.innerHTML = h;
  reviewCalendarDays.querySelectorAll('[data-rdate]').forEach(
    (b) =>
      (b.onclick = () => {
        selectedReviewDate = b.dataset.rdate;
        closeModal('reviewCalModal');
        renderReview();
      }),
  );
}
function meDoneCount() {
  return S.tasks.reduce((n, t) => n + Object.values(t.done || {}).filter(Boolean).length, 0);
}
function meNoteCount() {
  return Object.values(S.notes).reduce((n, v) => n + (Array.isArray(v) ? v.length : 0), 0);
}
function avatarFallback() {
  return (
    'data:image/svg+xml;charset=UTF-8,' +
    encodeURIComponent(
      '<svg xmlns="http://www.w3.org/2000/svg" width="140" height="140" viewBox="0 0 140 140"><rect width="140" height="140" fill="%2320262e"/><circle cx="70" cy="52" r="24" fill="%236b7682"/><path d="M28 128c5-30 23-45 42-45s37 15 42 45" fill="%236b7682"/></svg>',
    )
  );
}
function renderMe() {
  applyUiSize();
  const fallback = avatarFallback(),
    src = S.settings.avatar || fallback;
  const a = document.getElementById('avatarImg'),
    preview = document.getElementById('profileAvatarPreview');
  if (a) a.src = src;
  if (preview) preview.src = src;
  const name = S.settings.name || 'OneDay',
    sig = S.settings.signature || '记录生活，成为更好的自己。';
  document.getElementById('meProfileName') &&
    (document.getElementById('meProfileName').textContent = name);
  document.getElementById('meProfileSub') &&
    (document.getElementById('meProfileSub').textContent = sig);
  document.getElementById('meStatDays') &&
    (document.getElementById('meStatDays').textContent = recordDates().length);
  document.getElementById('meStatNotes') &&
    (document.getElementById('meStatNotes').textContent = meNoteCount());
  document.getElementById('meStatDone') &&
    (document.getElementById('meStatDone').textContent = meDoneCount());
  const tl = document.getElementById('themeLabel');
  if (tl)
    tl.textContent =
      S.settings.theme === 'light' ? '浅色' : S.settings.theme === 'dark' ? '深色' : '跟随系统';
}
function openProfile() {
  document.getElementById('profileNameInput').value = S.settings.name || 'OneDay';
  document.getElementById('profileSignatureInput').value =
    S.settings.signature || '记录生活，成为更好的自己。';
  document.getElementById('profileAvatarPreview').src = S.settings.avatar || avatarFallback();
  openModal('profileModal');
}
function saveProfile() {
  const name = document.getElementById('profileNameInput').value.trim().slice(0, 20) || 'OneDay';
  const signature =
    document.getElementById('profileSignatureInput').value.trim().slice(0, 80) ||
    '记录生活，成为更好的自己。';
  S.settings.name = name;
  S.settings.signature = signature;
  save();
  renderMe();
  closeModal('profileModal');
  toast('个人资料已保存');
}
function openDataManage() {
  openModal('dataManageModal');
}
function openAboutPage() {
  openModal('aboutModal');
}
function showVersionInfo() {
  closeModal('aboutModal');
  infoTitle.textContent = '版本信息';
  infoText.textContent =
    'OneDay v0.6\n\n本版本更新：\n• 移除计划左滑删除、右滑编辑手势，恢复普通按钮操作\n• 修复 iOS 键盘弹出后计划输入内容被滚到屏幕外的问题\n• 全部事项完成后弹出一句励志话和作者，完成当天只提示一次\n• 增加励志语句轮换，支持名人名言和原创提示\n• 清理重复覆盖代码，统一计划编辑、版本信息和初始化逻辑\n• 底栏五个图标统一为同一套细线几何风格\n• 支持 IndexedDB 自动保存、JSON 导入导出和 GitHub Pages 离线缓存';
  openModal('infoModal');
}
avatarInput.onchange = (e) => {
  const f = e.target.files?.[0];
  e.target.value = '';
  if (!f) return;
  if (f.size > 4 * 1024 * 1024) return toast('图片请小于 4MB');
  const r = new FileReader();
  r.onload = () => {
    S.settings.avatar = String(r.result);
    save();
    renderMe();
    document.getElementById('profileAvatarPreview') &&
      (document.getElementById('profileAvatarPreview').src = S.settings.avatar);
    toast('头像已更换');
  };
  r.readAsDataURL(f);
};
function openTheme() {
  pendingTheme = S.settings.theme;
  pendingAccent = S.settings.accent;
  renderThemeChoices();
  openModal('themeModal');
}
function renderThemeChoices() {
  document
    .querySelectorAll('[data-theme-choice]')
    .forEach((b) => b.classList.toggle('active', b.dataset.themeChoice === pendingTheme));
  colorChoices.innerHTML = colors
    .map(
      (c) =>
        `<button class="colorDot ${c === pendingAccent ? 'active' : ''}" data-color="${c}" style="background:${c}"></button>`,
    )
    .join('');
  document.querySelectorAll('[data-theme-choice]').forEach(
    (b) =>
      (b.onclick = () => {
        pendingTheme = b.dataset.themeChoice;
        renderThemeChoices();
      }),
  );
  colorChoices.querySelectorAll('[data-color]').forEach(
    (b) =>
      (b.onclick = () => {
        pendingAccent = b.dataset.color;
        renderThemeChoices();
      }),
  );
}
function saveTheme() {
  S.settings.theme = pendingTheme;
  S.settings.accent = pendingAccent;
  save();
  applyTheme();
  renderMe();
  closeModal('themeModal');
  toast('主题已保存');
}
function exportData() {
  const a = document.createElement('a'),
    u = URL.createObjectURL(new Blob([JSON.stringify(S, null, 2)], { type: 'application/json' }));
  a.href = u;
  a.download = 'oneday-backup.json';
  a.click();
  setTimeout(() => URL.revokeObjectURL(u), 800);
  toast('数据已导出');
}
importInput.onchange = (e) => {
  const f = e.target.files?.[0];
  e.target.value = '';
  if (!f) return;
  if (f.size > 10 * 1024 * 1024) return toast('备份文件不能超过 10MB');
  const r = new FileReader();
  r.onload = () => {
    try {
      const raw = JSON.parse(String(r.result || ''));
      if (!raw || typeof raw !== 'object') throw new Error('invalid');
      const incoming = normalize(raw);
      if (!confirm('导入会替换当前设备中的 OneDay 数据，建议先导出备份。确定继续吗？')) return;
      S = incoming;
      save();
      applyTheme();
      renderToday();
      renderTasks();
      renderPlans();
      renderReview();
      renderMe();
      toast('数据已导入');
    } catch {
      toast('无法识别这个备份文件');
    }
  };
  r.onerror = () => toast('读取备份失败');
  r.readAsText(f, 'utf-8');
};
let restoreReturnToDataManage = false;
function openRestore() {
  restoreReturnToDataManage = false;
  openModal('restoreModal');
}
function openRestoreFromDataManage() {
  restoreReturnToDataManage = true;
  closeModal('dataManageModal');
  openModal('restoreModal');
}
function cancelRestore() {
  closeModal('restoreModal');
  if (restoreReturnToDataManage) {
    restoreReturnToDataManage = false;
    openModal('dataManageModal');
  }
}
function restoreAllData() {
  if (
    !confirm(
      '确定恢复初始设置吗？这会清除头像、主题、事项、计划、回顾记录、完成历史和统计数据，且无法撤销。',
    )
  )
    return;
  if (!confirm('请再次确认：所有 OneDay 数据都会被清空。确定恢复到初始状态吗？')) return;
  S = blankState();
  selected = keyOf(D());
  viewMonth = new Date(D().getFullYear(), D().getMonth(), 1);
  reviewMonth = new Date(viewMonth);
  selectedReviewDate = null;
  reviewTab = 'timeline';
  reviewOverviewMonth = new Date(viewMonth);
  taskFilter = 'all';
  taskTab = 'today';
  pendingTheme = S.settings.theme;
  pendingAccent = S.settings.accent;
  save();
  applyTheme();
  restoreReturnToDataManage = false;
  closeModal('restoreModal');
  renderToday();
  renderTasks();
  renderPlans();
  renderReview();
  renderMe();
  toast('已恢复初始状态');
}
function openHelp() {
  infoTitle.textContent = '使用说明';
  infoText.textContent =
    '今天：记录当天的想法并完成事项。\n事项：查看今日、日历和完成统计。\n计划：管理长期方向，可完成或归档。\n回顾：只回看真实记录，不把人生变成任务成绩单。';
  openModal('infoModal');
}
function openAbout() {
  infoTitle.textContent = 'OneDay';
  infoText.textContent = '记录生活，成为更好的自己。\n\nOneDay v0.6';
  openModal('infoModal');
}

function openPhotoPreview(src) {
  const box = document.getElementById('photoLightbox');
  const img = document.getElementById('photoLightboxImage');
  if (!box || !img || !src) return;
  img.src = src;
  box.classList.add('open');
  box.setAttribute('aria-hidden', 'false');
  document.body.style.overflow = 'hidden';
}
function closePhotoPreview() {
  const box = document.getElementById('photoLightbox');
  const img = document.getElementById('photoLightboxImage');
  if (!box) return;
  box.classList.remove('open');
  box.setAttribute('aria-hidden', 'true');
  document.body.style.overflow = '';
  setTimeout(() => {
    if (!box.classList.contains('open') && img) img.removeAttribute('src');
  }, 180);
}

/* v0.6: review owns all completion aggregation; individual/all record deletion; floating iOS nav island. */
function syncNavHeight() {
  const nav = document.querySelector('.nav');
  if (!nav) return;
  document.documentElement.style.setProperty(
    '--nav-h',
    Math.ceil(nav.getBoundingClientRect().height || 86) + 'px',
  );
}
function syncViewportHeight() {
  const height = Math.round(window.visualViewport?.height || window.innerHeight || 0);
  if (height) document.documentElement.style.setProperty('--viewport-height', `${height}px`);
}
function scheduleNavSync() {
  requestAnimationFrame(() =>
    requestAnimationFrame(() => {
      syncNavHeight();
      syncViewportHeight();
    }),
  );
}
window.addEventListener('pageshow', scheduleNavSync, { passive: true });
window.addEventListener('resize', scheduleNavSync, { passive: true });
window.addEventListener('orientationchange', scheduleNavSync, { passive: true });
window.visualViewport?.addEventListener('resize', scheduleNavSync, { passive: true });
window.visualViewport?.addEventListener('scroll', scheduleNavSync, { passive: true });
function setupInputFocus() {
  document.addEventListener(
    'focusin',
    (e) => {
      const field = e.target.closest('input,textarea,select');
      if (!field) return;
      document.body.classList.add('keyboard-active');
      const sheet = field.closest('.sheet');
      requestAnimationFrame(() => {
        if (sheet) field.scrollIntoView({ block: 'nearest', inline: 'nearest', behavior: 'auto' });
      });
    },
    { passive: true },
  );
  document.addEventListener(
    'focusout',
    () =>
      setTimeout(() => {
        if (!document.activeElement?.matches('input,textarea,select'))
          document.body.classList.remove('keyboard-active');
      }, 120),
    { passive: true },
  );
}
function showMotivation(k) {
  const quote =
    motivations[
      Math.abs([...String(k)].reduce((n, c) => n + c.charCodeAt(0), 0)) % motivations.length
    ];
  motivationText.textContent = `“${quote.text}”\n\n—— ${quote.author}`;
  openModal('motivationModal');
}
document.documentElement.classList.add('oneday-v0488');
applyTheme();
applyUiSize();
save();
renderToday();
renderTasks();
renderPlans();
renderReview();
renderMe();
scheduleNavSync();
initStorage();
setupInputFocus();
if ('serviceWorker' in navigator && location.protocol !== 'file:') {
  navigator.serviceWorker
    .register('./service-worker.js')
    .catch((error) => console.warn('OneDay service worker unavailable', error));
}

/* v0.6: IndexedDB 恢复与 iOS 系统外观变化后的显示同步 */
function syncRuntimeAppearance() {
  applyTheme();
  applyUiSize();
  if (typeof applyAppearanceSettings === 'function') applyAppearanceSettings();
}
window.addEventListener('pageshow', () => setTimeout(syncRuntimeAppearance, 120), {
  passive: true,
});
const systemThemeQuery = window.matchMedia?.('(prefers-color-scheme: dark)');
systemThemeQuery?.addEventListener?.('change', () => {
  if (S.settings.theme === 'system') applyTheme();
});

/* iOS 26 聚焦兜底：对动态创建的输入控件再次确认安全字号 */
document.addEventListener(
  'focusin',
  (event) => {
    const field = event.target.closest?.('input,textarea,select,[contenteditable="true"]');
    if (!field) return;
    const size = parseFloat(getComputedStyle(field).fontSize);
    if (!Number.isFinite(size) || size < 16) field.style.fontSize = '16px';
    field.style.webkitTextSizeAdjust = '100%';
  },
  { passive: true },
);

/* v0.6: 按确认需求，回顾只保留普通编辑/删除按键，取消左滑；移除记录提示点 */
let editingReviewEntry = null;
function openEditReviewEntry(k, i) {
  const n = S.notes[k]?.[i];
  if (!n) return;
  editingReviewEntry = { k, i };
  const title = document.querySelector('#noteModal h3');
  if (title) title.textContent = '编辑这条记录';
  noteInput.value = n.text || '';
  openModal('noteModal');
}
const _saveNote516 = saveNote;
saveNote = function () {
  if (!editingReviewEntry) return _saveNote516();
  const { k, i } = editingReviewEntry,
    n = S.notes[k]?.[i],
    text = noteInput.value.trim();
  if (!n) return;
  if (!text && !n.photos?.length) return toast('记录不能是空的');
  n.text = text;
  save();
  editingReviewEntry = null;
  const title = document.querySelector('#noteModal h3');
  if (title) title.textContent = '今天有什么值得留下的吗？';
  closeModal('noteModal');
  renderReview();
  renderToday();
  toast('记录已更新');
};
const _openNote516 = openNote;
openNote = function () {
  editingReviewEntry = null;
  const title = document.querySelector('#noteModal h3');
  if (title) title.textContent = '今天有什么值得留下的吗？';
  _openNote516();
};
bindReviewEntrySwipe = function (root) {
  root.querySelectorAll('[data-review-swipe]').forEach((row) => {
    const card = row.querySelector('.reviewFocusEntry');
    if (!card) return;
    row.classList.remove('swiped');
    row.querySelector('.reviewSwipeDelete')?.remove();
    row.querySelector('.reviewSwipeActions')?.remove();
    card.style.transform = '';
    card.style.transition = '';
    card.style.touchAction = 'auto';
    const head = card.querySelector('.reviewEntryHead');
    if (!head || head.querySelector('.reviewEntryActions')) return;
    const actions = document.createElement('div');
    actions.className = 'reviewEntryActions';
    const edit = document.createElement('button');
    edit.type = 'button';
    edit.className = 'reviewEditBtn';
    edit.textContent = '编辑';
    edit.onclick = () =>
      openEditReviewEntry(row.dataset.reviewDate, Number(row.dataset.reviewIndex));
    const del = document.createElement('button');
    del.type = 'button';
    del.className = 'reviewDeleteBtn';
    del.textContent = '删除';
    del.onclick = () => deleteReviewEntry(row.dataset.reviewDate, Number(row.dataset.reviewIndex));
    actions.append(edit, del);
    head.appendChild(actions);
  });
};
reviewMarkers = () => '';
const _renderTasks516 = renderTasks;
renderTasks = function () {
  _renderTasks516();
  document.querySelector('[data-clear-day]')?.remove();
};
document.querySelector('#taskPanelToday .sectionHead .linkBtn')?.remove();
if (document.querySelector('#review.active')) renderReview();

/* v0.6: focused UI, accessible deletion, night theme and iOS keyboard stability. */
(function () {
  const VERSION = 'v0.6';
  const style = document.createElement('style');
  style.textContent = `
    html[data-card-style="soft"] .card,html[data-card-style="soft"] .reviewFocusCard,html[data-card-style="soft"] .reviewTasksCard{box-shadow:0 10px 28px rgba(31,40,48,.07)}
    html[data-card-style="flat"] .card,html[data-card-style="flat"] .reviewFocusCard,html[data-card-style="flat"] .reviewTasksCard{box-shadow:none!important;border-radius:10px!important}
    html[data-theme="dark"] body{background:radial-gradient(circle at 78% 8%,rgba(91,111,157,.14),transparent 22rem),#11161d}
    html[data-theme="dark"] body:before{content:'';position:fixed;inset:0;pointer-events:none;background:linear-gradient(120deg,transparent 47%,rgba(214,230,255,.28) 49%,transparent 51%) 74% 12%/140px 1px no-repeat,radial-gradient(circle at 20% 16%,rgba(255,255,255,.48) 0 1px,transparent 2px),radial-gradient(circle at 78% 33%,rgba(255,255,255,.30) 0 1px,transparent 2px)}
    .customColorChoice{display:inline-grid;place-items:center;width:42px;height:42px;margin:10px 0 0;border:1px solid var(--line);border-radius:50%;overflow:hidden;vertical-align:middle;color:var(--muted)} .customColorChoice input{position:absolute;width:42px;height:42px;opacity:0;cursor:pointer}
    .reviewPhotoWrap{position:relative;display:inline-block}.reviewPhotoDelete{position:absolute;right:6px;top:6px;width:28px;height:28px;border:0;border-radius:50%;background:rgba(18,24,30,.76);color:#fff;font-size:18px;line-height:1}.nav button.navFeedback{animation:oneday-nav-feedback 1.25s ease both}@keyframes oneday-nav-feedback{0%,100%{transform:scale(1)}35%{transform:scale(.91);background:color-mix(in srgb,var(--accent) 17%,var(--surface))}65%{transform:scale(1.04)}}
    .settingIcon{font-family:system-ui,sans-serif;font-weight:650}.settingIcon.iconUnified{width:26px;height:26px;display:grid;place-items:center;border:1.5px solid currentColor;border-radius:8px;font-size:13px}
  `;
  document.head.append(style);
  document.querySelectorAll('.meStats').forEach((x) => x.remove());
  document.querySelectorAll('.aboutVersion').forEach((x) => (x.textContent = VERSION));
  document.querySelectorAll('.settingValue').forEach((x) => {
    if (/^v0\./.test(x.textContent.trim())) x.textContent = VERSION;
  });
  document
    .querySelectorAll('.meFooter')
    .forEach((x) => (x.innerHTML = x.innerHTML.replace(/OneDay v0\.\d+/g, 'OneDay ' + VERSION)));
  document.querySelectorAll('.settingIcon').forEach((x) => x.classList.add('iconUnified'));

  const baseGo = go;
  go = function (id) {
    const active = document.querySelector('.nav button.active[data-go="' + id + '"]');
    if (active) {
      active.classList.remove('navFeedback');
      void active.offsetWidth;
      active.classList.add('navFeedback');
      setTimeout(() => active.classList.remove('navFeedback'), 1250);
    }
    baseGo(id);
  };

  applyAppearanceSettings = function () {
    const s = S.settings || {};
    s.cardStyle = s.cardStyle === 'flat' ? 'flat' : 'soft';
    s.bgTone = ['warm', 'cool', 'gray'].includes(s.bgTone) ? s.bgTone : 'warm';
    s.reduceMotion = Boolean(s.reduceMotion);
    delete s.startPage;
    S.settings = s;
    document.documentElement.dataset.cardStyle = s.cardStyle;
    document.documentElement.dataset.bgTone = s.bgTone;
    document.documentElement.dataset.reduceMotion = s.reduceMotion ? 'true' : 'false';
    const labels = { soft: '柔和卡片', flat: '纯净平面', warm: '暖白', cool: '冷白', gray: '浅灰' };
    const row = document.getElementById('appearanceLabel');
    if (row) row.textContent = labels[s.cardStyle] + ' · ' + labels[s.bgTone];
    document
      .querySelectorAll('[data-appearance-choice]')
      .forEach((b) =>
        b.classList.toggle(
          'active',
          b.dataset.appearanceChoice === String(s[b.dataset.appearanceKey]),
        ),
      );
    const motion = document.getElementById('reduceMotionChoice');
    if (motion) motion.checked = s.reduceMotion;
  };
  openAppearanceSettings = function () {
    let modal = document.getElementById('appearanceModal');
    if (!modal) {
      document.body.insertAdjacentHTML(
        'beforeend',
        '<div class="modal" id="appearanceModal"><div class="sheet"><h3>显示偏好</h3><div class="appearanceGroup"><label>卡片样式</label><div class="appearanceChoices"><button class="appearanceChoice" data-appearance-key="cardStyle" data-appearance-choice="soft">柔和卡片</button><button class="appearanceChoice" data-appearance-key="cardStyle" data-appearance-choice="flat">纯净平面</button></div></div><div class="appearanceGroup"><label>背景色调</label><div class="appearanceChoices"><button class="appearanceChoice" data-appearance-key="bgTone" data-appearance-choice="warm">暖白</button><button class="appearanceChoice" data-appearance-key="bgTone" data-appearance-choice="cool">冷白</button><button class="appearanceChoice" data-appearance-key="bgTone" data-appearance-choice="gray">浅灰</button></div></div><label class="appearanceToggle"><span>减少动效<div class="settingDesc">更接近 iOS 的低动态效果</div></span><input id="reduceMotionChoice" type="checkbox"></label><div class="sheetActions"><button class="primary" type="button" onclick="closeModal(\'appearanceModal\')">完成</button></div></div></div>',
      );
      modal = document.getElementById('appearanceModal');
      modal.addEventListener('click', (e) => {
        if (e.target === modal) closeModal('appearanceModal');
      });
      modal
        .querySelectorAll('[data-appearance-choice]')
        .forEach(
          (b) =>
            (b.onclick = () =>
              saveAppearanceSetting(b.dataset.appearanceKey, b.dataset.appearanceChoice)),
        );
      modal.querySelector('#reduceMotionChoice').onchange = (e) =>
        saveAppearanceSetting('reduceMotion', e.target.checked);
    }
    applyAppearanceSettings();
    openModal('appearanceModal');
  };

  function continuousCompletionDays(month) {
    const b = monthBounds(month),
      days = new Set();
    S.tasks.forEach((t) =>
      Object.entries(t.done || {}).forEach(([k, v]) => {
        if (v && k >= b.start && k <= b.end) days.add(k);
      }),
    );
    let best = 0,
      current = 0;
    for (
      let d = new Date(month.getFullYear(), month.getMonth(), 1);
      d.getMonth() === month.getMonth();
      d.setDate(d.getDate() + 1)
    ) {
      if (days.has(keyOf(d))) {
        current++;
        best = Math.max(best, current);
      } else current = 0;
    }
    return best;
  }
  function textRecordCount(month) {
    const b = monthBounds(month);
    return Object.entries(S.notes).reduce(
      (n, [k, items]) =>
        n + (k >= b.start && k <= b.end ? (items || []).filter((x) => x.text?.trim()).length : 0),
      0,
    );
  }
  renderReviewOverview = function () {
    const data = monthlyOverview(reviewOverviewMonth),
      label = `${reviewOverviewMonth.getFullYear()}年${reviewOverviewMonth.getMonth() + 1}月`,
      max = Math.max(1, ...data.items.map((x) => x.count));
    reviewList.innerHTML = `<div class="overviewMonth"><button aria-label="上个月" onclick="changeOverviewMonth(-1)">‹</button><strong>${label}</strong><button aria-label="下个月" onclick="changeOverviewMonth(1)">›</button></div><section class="overviewHero"><div class="overviewHeroLabel">本月完成事项</div><div class="overviewHeroRow"><div class="overviewHeroNum">${data.total}<span>次</span></div><div class="overviewHeroSub">每一次完成，都是<br>真实发生过的一天。</div></div></section><section class="overviewList"><div class="overviewListHead"><span>各事项完成次数</span><span class="small">${data.items.length ? `${data.items.length} 个事项` : '暂无数据'}</span></div>${data.items.length ? data.items.map((x) => `<div class="overviewItem"><div class="overviewItemName">${esc(x.title)}</div><div class="overviewItemCount">${x.count} 次</div><div class="overviewBar"><i style="width:${Math.max(8, Math.round((x.count / max) * 100))}%"></i></div></div>`).join('') : '<div class="overviewEmpty">这个月还没有完成记录。<br>完成一次事项后，这里会自动出现。</div>'}</section><section class="overviewStats"><div class="overviewStat"><span>连续完成</span><strong>${continuousCompletionDays(reviewOverviewMonth)} 天</strong></div><div class="overviewStat"><span>留下文字</span><strong>${textRecordCount(reviewOverviewMonth)} 条</strong></div><div class="overviewStat"><span>留下文字</span><strong>${data.noteDays} 天</strong></div></section>`;
  };
  window.deleteReviewPhoto = function (k, i, j) {
    const photos = S.notes[k]?.[i]?.photos;
    if (!photos?.[j] || !confirm('只删除这张照片？文字和其他照片会保留。')) return;
    photos.splice(j, 1);
    save();
    renderReview();
    renderToday();
    toast('照片已删除');
  };
  const baseTimeline = renderReviewTimeline;
  renderReviewTimeline = function () {
    baseTimeline();
    if (!selectedReviewDate) return;
    reviewList.querySelectorAll('.reviewPhotos').forEach((box) => {
      const row = box.closest('[data-review-index]'),
        k = row?.dataset.reviewDate,
        i = Number(row?.dataset.reviewIndex);
      [...box.querySelectorAll('img.reviewPhoto')].forEach((img, j) => {
        const wrap = document.createElement('span');
        wrap.className = 'reviewPhotoWrap';
        img.before(wrap);
        wrap.append(img);
        const del = document.createElement('button');
        del.className = 'reviewPhotoDelete';
        del.type = 'button';
        del.setAttribute('aria-label', '删除这张照片');
        del.textContent = '×';
        del.onclick = (e) => {
          e.stopPropagation();
          window.deleteReviewPhoto(k, i, j);
        };
        wrap.append(del);
      });
    });
  };
  showVersionInfo = function () {
    closeModal('aboutModal');
    infoTitle.textContent = '版本信息';
    infoText.textContent =
      'OneDay v0.6\n\n本版本更新：\n• 回顾记录新增单独删除照片，文字与其他照片不受影响\n• 精简“我的”页面，移除统计区域并统一设置图标\n• 删除显示偏好中的启动页面；强化柔和卡片与纯净平面的视觉差异\n• 新增简洁流星夜主题与自定义主题色\n• 完成概览改为连续完成，并新增文字记录条数\n• 每日导航增加短暂停留反馈\n• 优化 iOS 26/27 键盘聚焦，避免输入框被强制顶到页面顶部\n• 修复显示偏好入口、彩虹调色盘、流星夜背景与照片全屏预览\n• 今日事项点击增加短暂停留反馈；连续完成按当月最长连续完成天数计算';
    openModal('infoModal');
  };
  const oldRenderTheme = renderThemeChoices;
  renderThemeChoices = function () {
    oldRenderTheme();
    const input = document.getElementById('customAccentInput');
    if (!input) return;
    input.value = pendingAccent || S.settings.accent || '#287052';
    input.oninput = (e) => {
      pendingAccent = e.target.value;
      if (!colors.includes(pendingAccent)) colors.push(pendingAccent);
      renderThemeChoices();
    };
  };
  const oldSaveTheme = saveTheme;
  saveTheme = function () {
    if (pendingAccent && !colors.includes(pendingAccent)) colors.push(pendingAccent);
    oldSaveTheme();
  };
  window.visualViewport?.addEventListener(
    'resize',
    () => {
      if (document.activeElement?.matches('input,textarea,select'))
        document.documentElement.style.setProperty(
          '--viewport-height',
          `${Math.round(window.visualViewport.height)}px`,
        );
    },
    { passive: true },
  );
  const baseOpenPhotoPreview = openPhotoPreview,
    baseClosePhotoPreview = closePhotoPreview;
  let photoScrollY = 0;
  openPhotoPreview = function (src) {
    photoScrollY = window.scrollY || 0;
    document.body.classList.add('photo-preview-open');
    document.body.style.top = '-' + photoScrollY + 'px';
    baseOpenPhotoPreview(src);
  };
  closePhotoPreview = function () {
    baseClosePhotoPreview();
    document.body.classList.remove('photo-preview-open');
    document.body.style.top = '';
    window.scrollTo(0, photoScrollY);
  };
  document.querySelector('[data-home-module="tasks"]')?.addEventListener('click', () => {
    const card = document.getElementById('todayTasks');
    if (!card) return;
    card.classList.remove('todayTasksFeedback');
    void card.offsetWidth;
    card.classList.add('todayTasksFeedback');
    setTimeout(() => card.classList.remove('todayTasksFeedback'), 1350);
  });
  applyAppearanceSettings();
})();

/* v0.6: explicit display preferences, single custom color and task-completion feedback. */
(function () {
  const BASE_COLORS = ['#287052', '#386b98', '#8057b8', '#c75c88', '#d77b48', '#68717a'];
  let pendingCustomAccent = null;
  const style = document.createElement('style');
  style.textContent = `
    html[data-bg-tone="meteor"]{--bg:#0b1018;--surface:#151c26;--surface2:#1a2330;--line:#2c3949;--ink:#edf2f7;--muted:#aab7c5;color-scheme:dark}
    html[data-bg-tone="meteor"] body{background:radial-gradient(ellipse at 22% 12%,rgba(59,95,142,.24),transparent 28%),linear-gradient(118deg,transparent 0 42%,rgba(225,239,255,.75) 46%,rgba(134,178,227,.3) 47%,transparent 50%) 42% 16%/46rem 2px no-repeat,linear-gradient(128deg,transparent 0 48%,rgba(225,239,255,.55) 50%,transparent 52%) 74% 34%/32rem 1px no-repeat,#0b1018}
    html[data-bg-tone="meteor"] body:before{content:'';position:fixed;inset:0;pointer-events:none;background:radial-gradient(circle at 12% 20%,#fff 0 1px,transparent 1.5px),radial-gradient(circle at 81% 14%,#dceaff 0 1px,transparent 1.5px),radial-gradient(circle at 63% 42%,#fff 0 1px,transparent 1.5px),radial-gradient(circle at 31% 66%,#cad9e9 0 1px,transparent 1.5px)}
    .taskCompleteFeedback .check,.taskCompleteFeedback .taskTitle,.taskCompleteFeedback .taskMeta{animation:task-complete-feedback 1.35s ease both}@keyframes task-complete-feedback{0%,100%{transform:translateX(0);filter:none}28%{transform:translateX(3px) scale(1.04);filter:drop-shadow(0 3px 7px color-mix(in srgb,var(--accent) 35%,transparent))}58%{transform:translateX(0) scale(1.01)}}
    .customColorChoice{display:inline-block!important;vertical-align:top;margin-left:12px!important}
  `;
  document.head.append(style);
  colors.splice(0, colors.length, ...BASE_COLORS);
  if (/^#[0-9a-f]{6}$/i.test(S.settings.customAccent || '')) {
    colors.push(S.settings.customAccent);
    S.settings.accent = S.settings.customAccent;
    applyTheme();
  }
  applyAppearanceSettings = function () {
    const s = S.settings || {};
    s.cardStyle = s.cardStyle === 'flat' ? 'flat' : 'soft';
    s.bgTone = ['warm', 'cool', 'gray', 'meteor'].includes(s.bgTone) ? s.bgTone : 'warm';
    delete s.reduceMotion;
    delete s.startPage;
    S.settings = s;
    document.documentElement.dataset.cardStyle = s.cardStyle;
    document.documentElement.dataset.bgTone = s.bgTone;
    const labels = {
      soft: '柔和卡片',
      flat: '纯净平面',
      warm: '暖白',
      cool: '冷白',
      gray: '浅灰',
      meteor: '流星夜',
    };
    const row = document.getElementById('appearanceLabel');
    if (row) row.textContent = labels[s.cardStyle] + ' · ' + labels[s.bgTone];
    document
      .querySelectorAll('[data-appearance-choice]')
      .forEach((b) =>
        b.classList.toggle(
          'active',
          b.dataset.appearanceChoice === String(s[b.dataset.appearanceKey]),
        ),
      );
  };
  saveAppearanceSetting = function (key, value) {
    S.settings[key] = value;
    applyAppearanceSettings();
    save();
    toast('显示偏好已保存');
  };
  openAppearanceSettings = function () {
    let modal = document.getElementById('appearanceModal');
    if (!modal) {
      document.body.insertAdjacentHTML(
        'beforeend',
        '<div class="modal" id="appearanceModal"><div class="sheet"><h3>显示偏好</h3><div class="appearanceGroup"><label>卡片样式</label><div class="appearanceChoices"><button class="appearanceChoice" data-appearance-key="cardStyle" data-appearance-choice="soft">柔和卡片</button><button class="appearanceChoice" data-appearance-key="cardStyle" data-appearance-choice="flat">纯净平面</button></div></div><div class="appearanceGroup"><label>背景色调</label><div class="appearanceChoices"><button class="appearanceChoice" data-appearance-key="bgTone" data-appearance-choice="warm">暖白</button><button class="appearanceChoice" data-appearance-key="bgTone" data-appearance-choice="cool">冷白</button><button class="appearanceChoice" data-appearance-key="bgTone" data-appearance-choice="gray">浅灰</button><button class="appearanceChoice" data-appearance-key="bgTone" data-appearance-choice="meteor">流星夜</button></div></div><div class="sheetActions"><button class="primary" type="button" onclick="closeModal(\'appearanceModal\')">完成</button></div></div></div>',
      );
      modal = document.getElementById('appearanceModal');
      modal.addEventListener('click', (e) => {
        if (e.target === modal) closeModal('appearanceModal');
      });
      modal
        .querySelectorAll('[data-appearance-choice]')
        .forEach(
          (b) =>
            (b.onclick = () =>
              saveAppearanceSetting(b.dataset.appearanceKey, b.dataset.appearanceChoice)),
        );
    }
    applyAppearanceSettings();
    openModal('appearanceModal');
  };
  openTheme = function () {
    pendingTheme = S.settings.theme;
    pendingAccent = S.settings.accent;
    pendingCustomAccent = S.settings.customAccent || null;
    renderThemeChoices();
    openModal('themeModal');
  };
  renderThemeChoices = function () {
    colors.splice(0, colors.length, ...BASE_COLORS);
    if (pendingCustomAccent) colors.push(pendingCustomAccent);
    colorChoices.innerHTML = colors
      .map(
        (c) =>
          `<button class="colorDot ${c === pendingAccent ? 'active' : ''}" data-color="${c}" style="background:${c}"></button>`,
      )
      .join('');
    document.querySelectorAll('[data-theme-choice]').forEach((b) => {
      b.classList.toggle('active', b.dataset.themeChoice === pendingTheme);
      b.onclick = () => {
        pendingTheme = b.dataset.themeChoice;
        renderThemeChoices();
      };
    });
    colorChoices.querySelectorAll('[data-color]').forEach(
      (b) =>
        (b.onclick = () => {
          pendingAccent = b.dataset.color;
          pendingCustomAccent = BASE_COLORS.includes(pendingAccent) ? null : pendingAccent;
          renderThemeChoices();
        }),
    );
    const input = document.getElementById('customAccentInput');
    if (input) {
      input.value = pendingCustomAccent || pendingAccent || '#287052';
      input.oninput = (e) => {
        pendingAccent = e.target.value;
        pendingCustomAccent = e.target.value;
        renderThemeChoices();
      };
    }
  };
  saveTheme = function () {
    colors.splice(0, colors.length, ...BASE_COLORS);
    if (pendingCustomAccent) {
      S.settings.customAccent = pendingCustomAccent;
      colors.push(pendingCustomAccent);
    } else delete S.settings.customAccent;
    S.settings.theme = pendingTheme;
    S.settings.accent = pendingAccent;
    save();
    applyTheme();
    renderMe();
    closeModal('themeModal');
    toast('主题已保存');
  };
  const baseToggleTask = toggleTask;
  toggleTask = function (id, k) {
    baseToggleTask(id, k);
    if (k !== keyOf(D())) return;
    const task = document
      .querySelector('#todayTasks .check[data-id="' + CSS.escape(id) + '"]')
      ?.closest('.task');
    if (!task) return;
    task.classList.remove('taskCompleteFeedback');
    void task.offsetWidth;
    task.classList.add('taskCompleteFeedback');
    setTimeout(() => task.classList.remove('taskCompleteFeedback'), 1350);
  };
  showVersionInfo = function () {
    closeModal('aboutModal');
    infoTitle.textContent = '版本信息';
    infoText.textContent =
      'OneDay v0.6\n\n本版本更新：\n• 修复显示偏好选项无法保存的问题，移除“减少动效”\n• 保留深色模式；流星夜改为背景色调中的独立夜间样式\n• 自定义主题色只保留一个圆点，后一次调色会覆盖前一次\n• 主页事项完成圆圈及同一行文字新增短暂停留反馈\n• 调整流星夜轨迹与照片预览稳定性';
    openModal('infoModal');
  };
  applyAppearanceSettings();
})();
/* v0.6 final interaction precedence. */
(function () {
  const style = document.createElement('style');
  style.textContent =
    'html[data-theme="dark"]:not([data-bg-tone="meteor"]) body{background:#151a20!important}html[data-theme="dark"]:not([data-bg-tone="meteor"]) body:before{content:none!important}';
  document.head.append(style);
  go = function (id) {
    document.querySelectorAll('.page').forEach((x) => x.classList.toggle('active', x.id === id));
    document
      .querySelectorAll('.nav button')
      .forEach((x) => x.classList.toggle('active', x.dataset.go === id));
    (
      ({
        today: renderToday,
        tasks: renderTasks,
        plans: renderPlans,
        review: renderReview,
        me: renderMe,
      })[id] || (() => {})
    )();
  };
})();
/* v0.6: note tags and review search. */
(function () {
  const DEFAULT_TAGS = ['日常', '心情', '灵感'];
  let pendingTaggedNote = null,
    selectedNoteTags = [];
  const style = document.createElement('style');
  style.textContent =
    '.reviewTopActions{display:flex;gap:8px}.tagChoices{display:flex;flex-wrap:wrap;gap:9px;margin:14px 0}.tagChoice{border:1px solid var(--line);border-radius:999px;background:var(--surface);color:var(--ink);padding:9px 13px;font:inherit;font-size:14px}.tagChoice.active{background:var(--accent);border-color:var(--accent);color:#fff}.tagAddRow{display:flex;gap:9px}.tagAddRow input,.tagSearchInput{min-width:0;flex:1;border:1px solid var(--line);border-radius:14px;padding:12px;background:var(--surface);color:var(--ink);font:inherit;font-size:16px}.tagAddRow .secondary{flex:0 0 auto}.tagSearchResults{display:grid;gap:9px;margin-top:12px}.tagSearchResult{width:100%;text-align:left;border:1px solid var(--line);border-radius:14px;background:var(--surface);padding:13px;color:var(--ink);font:inherit}.tagSearchResult small{display:block;color:var(--muted);margin-top:5px}.themeModeGlyph{display:inline-grid;place-items:center;width:20px;height:20px;border:1.5px solid currentColor;border-radius:50%;font-size:11px;line-height:1}';
  document.head.append(style);
  document
    .querySelector('[data-theme-choice="light"]')
    ?.replaceChildren(
      Object.assign(document.createElement('span'), {
        className: 'themeModeGlyph',
        textContent: '◐',
      }),
      document.createElement('br'),
      document.createTextNode('浅色'),
    );
  document
    .querySelector('[data-theme-choice="dark"]')
    ?.replaceChildren(
      Object.assign(document.createElement('span'), {
        className: 'themeModeGlyph',
        textContent: '◐',
      }),
      document.createElement('br'),
      document.createTextNode('深色'),
    );
  const reviewTop = document.querySelector('#review .top');
  if (reviewTop && !reviewTop.querySelector('.reviewTopActions')) {
    const calendar = reviewTop.querySelector('.iconBtn');
    const actions = document.createElement('div');
    actions.className = 'reviewTopActions';
    const search = document.createElement('button');
    search.type = 'button';
    search.className = 'iconBtn';
    search.textContent = '⌕';
    search.setAttribute('aria-label', '搜索标签');
    search.onclick = () => openTagSearch();
    actions.append(search);
    if (calendar) actions.append(calendar);
    reviewTop.append(actions);
  }
  document.body.insertAdjacentHTML(
    'beforeend',
    `<div class="modal" id="tagModal"><div class="sheet"><h3>给这条记录加标签</h3><p class="small">标签可选，也可以自己创建；以后可在回顾中按标签搜索。</p><div class="tagChoices" id="tagChoices"></div><div class="tagAddRow"><input id="newTagInput" maxlength="12" placeholder="新标签，例如：旅行"><button class="secondary" type="button" onclick="addCustomTag()">添加</button></div><div class="sheetActions"><button class="secondary" type="button" onclick="skipQuickNoteTag()">跳过</button><button class="primary" type="button" onclick="saveTaggedQuickNote()">保存记录</button></div></div></div><div class="modal" id="tagSearchModal"><div class="sheet"><div class="sheetHeader"><button class="sheetBack" type="button" onclick="closeModal('tagSearchModal')" aria-label="返回">‹</button><h3>搜索标签</h3></div><input class="tagSearchInput" id="tagSearchInput" placeholder="输入或选择标签" oninput="renderTagSearch()"><div class="tagChoices" id="tagSearchChoices"></div><div class="tagSearchResults" id="tagSearchResults"></div></div></div>`,
  );
  function allTags() {
    const custom = Array.isArray(S.settings.customTags) ? S.settings.customTags : [];
    return [...new Set([...DEFAULT_TAGS, ...custom])].slice(0, 24);
  }
  function renderTagChoices() {
    const box = document.getElementById('tagChoices');
    if (!box) return;
    box.innerHTML = allTags()
      .map(
        (tag) =>
          `<button type="button" class="tagChoice ${selectedNoteTags.includes(tag) ? 'active' : ''}" data-tag="${esc(tag)}">${esc(tag)}</button>`,
      )
      .join('');
    box.querySelectorAll('[data-tag]').forEach(
      (button) =>
        (button.onclick = () => {
          const tag = button.dataset.tag;
          selectedNoteTags = selectedNoteTags.includes(tag)
            ? selectedNoteTags.filter((x) => x !== tag)
            : [...selectedNoteTags, tag];
          renderTagChoices();
        }),
    );
  }
  window.addCustomTag = function () {
    const input = document.getElementById('newTagInput'),
      tag = input?.value.trim().slice(0, 12);
    if (!tag) return;
    if (!Array.isArray(S.settings.customTags)) S.settings.customTags = [];
    if (!S.settings.customTags.includes(tag)) S.settings.customTags.push(tag);
    if (!selectedNoteTags.includes(tag)) selectedNoteTags.push(tag);
    input.value = '';
    save();
    renderTagChoices();
  };
  window.skipQuickNoteTag = function () {
    selectedNoteTags = [];
    saveTaggedQuickNote();
  };
  window.saveTaggedQuickNote = function () {
    if (!pendingTaggedNote) return;
    const { text, photos, k, time } = pendingTaggedNote;
    S.notes[k] = S.notes[k] || [];
    S.notes[k].push({ text, time, photos, tags: [...selectedNoteTags] });
    save();
    pendingTaggedNote = null;
    selectedNoteTags = [];
    closeModal('tagModal');
    renderToday();
    renderReview();
    toast('已经留下来了');
  };
  saveQuickNote = function () {
    const input = document.getElementById('quickNoteInput'),
      text = input?.value.trim() || '';
    if (!text && !pendingQuickPhotos.length) return toast('写一点内容，或者留下一张照片');
    pendingTaggedNote = {
      text,
      photos: [...pendingQuickPhotos],
      k: keyOf(D()),
      time: `${pad(D().getHours())}:${pad(D().getMinutes())}`,
    };
    input.value = '';
    pendingQuickPhotos = [];
    const photoInput = document.getElementById('quickPhotoInput');
    if (photoInput) photoInput.value = '';
    renderQuickPhotoPreview();
    selectedNoteTags = [];
    renderTagChoices();
    openModal('tagModal');
  };
  window.openTagSearch = function () {
    const input = document.getElementById('tagSearchInput');
    if (input) input.value = '';
    renderTagSearch();
    openModal('tagSearchModal');
  };
  window.renderTagSearch = function () {
    const query = (document.getElementById('tagSearchInput')?.value || '').trim().toLowerCase(),
      choices = document.getElementById('tagSearchChoices'),
      results = document.getElementById('tagSearchResults');
    if (!choices || !results) return;
    choices.innerHTML = allTags()
      .map(
        (tag) =>
          `<button type="button" class="tagChoice" data-search-tag="${esc(tag)}">${esc(tag)}</button>`,
      )
      .join('');
    choices.querySelectorAll('[data-search-tag]').forEach(
      (button) =>
        (button.onclick = () => {
          document.getElementById('tagSearchInput').value = button.dataset.searchTag;
          renderTagSearch();
        }),
    );
    const found = [];
    Object.entries(S.notes).forEach(([k, notes]) =>
      (notes || []).forEach((note, i) => {
        const tags = note.tags || [];
        if (query && tags.some((tag) => tag.toLowerCase().includes(query)))
          found.push({ k, i, note, tags });
      }),
    );
    results.innerHTML = query
      ? found.length
        ? found
            .sort((a, b) => b.k.localeCompare(a.k))
            .map(
              (x) =>
                `<button type="button" class="tagSearchResult" data-result-date="${x.k}"><strong>${esc(x.note.text || '留下了一张照片')}</strong><small>${esc(x.k)} · ${x.tags.map(esc).join(' · ')}</small></button>`,
            )
            .join('')
        : '<div class="empty">没有找到带这个标签的记录。</div>'
      : '<div class="empty">选择一个标签，查看相关记录。</div>';
    results.querySelectorAll('[data-result-date]').forEach(
      (button) =>
        (button.onclick = () => {
          selectedReviewDate = button.dataset.resultDate;
          reviewTab = 'timeline';
          closeModal('tagSearchModal');
          go('review');
        }),
    );
  };
  showVersionInfo = function () {
    closeModal('aboutModal');
    infoTitle.textContent = '版本信息';
    infoText.textContent =
      'OneDay v0.6\n\n本版本更新：\n• 值得留下保存后可选择或创建标签\n• 回顾页右上新增标签搜索入口\n• 主题设置统一浅色与深色的图标样式\n• 完成概览将活跃天数调整为留下文字天数';
    openModal('infoModal');
  };
})();
/* v0.6: removable custom tags, highlighted review labels and iOS viewport anchoring. */
(function () {
  const style = document.createElement('style');
  style.textContent =
    '.tagChoiceWrap{position:relative;display:inline-flex}.tagChoiceWrap .tagChoice{padding-right:32px}.tagChoiceDelete{position:absolute;right:4px;top:50%;transform:translateY(-50%);width:23px;height:23px;border:0;border-radius:50%;background:transparent;color:var(--muted);font-size:18px;line-height:1}.tagChoiceDelete:active{background:color-mix(in srgb,var(--danger) 14%,transparent);color:var(--danger)}.reviewEntryTags{display:flex;flex-wrap:wrap;gap:6px;margin-top:11px}.reviewEntryTag{padding:4px 8px;border-radius:999px;background:color-mix(in srgb,var(--accent) 16%,var(--surface));border:1px solid color-mix(in srgb,var(--accent) 36%,var(--line));color:var(--accent);font-size:12px;font-weight:750}.keyboard-active .sheet{max-height:calc(var(--viewport-height,100dvh) - 8px)!important}.keyboard-active input,.keyboard-active textarea{scroll-margin-block:calc(28vh)}';
  document.head.append(style);
  function decorateCustomTagDeletes() {
    const box = document.getElementById('tagChoices');
    if (!box) return;
    box.querySelectorAll('[data-tag]').forEach((button) => {
      const tag = button.dataset.tag;
      if (
        !Array.isArray(S.settings.customTags) ||
        !S.settings.customTags.includes(tag) ||
        button.closest('.tagChoiceWrap')
      )
        return;
      const wrap = document.createElement('span');
      wrap.className = 'tagChoiceWrap';
      button.before(wrap);
      wrap.append(button);
      const del = document.createElement('button');
      del.type = 'button';
      del.className = 'tagChoiceDelete';
      del.setAttribute('aria-label', '删除标签 ' + tag);
      del.textContent = '×';
      del.onclick = (e) => {
        e.stopPropagation();
        deleteCustomTag(tag);
      };
      wrap.append(del);
    });
  }
  new MutationObserver(decorateCustomTagDeletes).observe(document.getElementById('tagChoices'), {
    childList: true,
  });
  window.deleteCustomTag = function (tag) {
    if (!Array.isArray(S.settings.customTags) || !S.settings.customTags.includes(tag)) return;
    if (!confirm(`删除标签“${tag}”？它会从所有历史记录中移除。`)) return;
    S.settings.customTags = S.settings.customTags.filter((x) => x !== tag);
    Object.values(S.notes).forEach((notes) =>
      (notes || []).forEach((note) => {
        note.tags = Array.isArray(note.tags) ? note.tags.filter((x) => x !== tag) : [];
      }),
    );
    save();
    document.querySelectorAll('[data-tag]').forEach((button) => {
      if (button.dataset.tag === tag) button.closest('.tagChoiceWrap')?.remove();
    });
    renderReview();
    toast('标签已删除');
  };
  const baseTimeline527 = renderReviewTimeline;
  renderReviewTimeline = function () {
    baseTimeline527();
    if (!selectedReviewDate) return;
    reviewList.querySelectorAll('[data-review-swipe]').forEach((row) => {
      const k = row.dataset.reviewDate,
        i = Number(row.dataset.reviewIndex),
        tags = S.notes[k]?.[i]?.tags || [];
      if (!tags.length) return;
      const entry = row.querySelector('.reviewFocusEntry');
      if (!entry || entry.querySelector('.reviewEntryTags')) return;
      const host = document.createElement('div');
      host.className = 'reviewEntryTags';
      host.innerHTML = tags
        .map((tag) => `<span class="reviewEntryTag"># ${esc(tag)}</span>`)
        .join('');
      const text = entry.querySelector('.reviewText');
      (text || entry.querySelector('.reviewEntryHead'))?.after(host);
    });
  };
  function alignFocusedField() {
    const field = document.activeElement?.closest?.('input,textarea,select');
    if (!field) return;
    const vv = window.visualViewport,
      sheet = field.closest('.sheet');
    if (sheet && vv) {
      sheet.style.height = Math.max(180, Math.round(vv.height - 8)) + 'px';
      sheet.style.maxHeight = 'none';
      sheet.style.overflowY = 'auto';
    }
    const align = () =>
      field.scrollIntoView({ block: 'center', inline: 'nearest', behavior: 'auto' });
    align();
    setTimeout(align, 80);
    setTimeout(align, 240);
  }
  document.addEventListener(
    'focusin',
    (e) => {
      if (e.target.matches('input,textarea,select')) {
        document.body.classList.add('keyboard-active');
        alignFocusedField();
      }
    },
    { passive: true },
  );
  window.visualViewport?.addEventListener('resize', alignFocusedField, { passive: true });
  window.visualViewport?.addEventListener('scroll', alignFocusedField, { passive: true });
  document.addEventListener(
    'focusout',
    () =>
      setTimeout(() => {
        if (document.activeElement?.matches('input,textarea,select')) return;
        document.body.classList.remove('keyboard-active');
        document.querySelectorAll('.sheet').forEach((sheet) => {
          sheet.style.height = '';
          sheet.style.maxHeight = '';
          sheet.style.overflowY = '';
        });
      }, 180),
    { passive: true },
  );
  showVersionInfo = function () {
    closeModal('aboutModal');
    infoTitle.textContent = '版本信息';
    infoText.textContent =
      'OneDay v0.6\n\n本版本更新：\n• 自定义标签支持删除，并同步清理历史记录中的标签\n• 回顾记录在文字下方高亮显示所属标签\n• 优化 iOS 27 键盘弹出时的输入框可视位置';
    openModal('infoModal');
  };
})();
/* v0.6: clearer review record boundaries and distinct theme icons. */
(function () {
  const style = document.createElement('style');
  style.textContent =
    '.reviewFocusCard{display:grid;gap:12px}.reviewFocusCard .reviewSwipeRow{border:1px solid var(--line);border-radius:16px;background:var(--surface);overflow:visible!important;box-shadow:0 4px 12px rgba(20,30,40,.035)}.reviewFocusCard .reviewFocusEntry{min-height:96px}.themeModeIcon{width:21px;height:21px;vertical-align:middle;stroke:currentColor;fill:none;stroke-width:1.8;stroke-linecap:round;stroke-linejoin:round}';
  document.head.append(style);
  const light = document.querySelector('[data-theme-choice="light"]'),
    dark = document.querySelector('[data-theme-choice="dark"]');
  if (light)
    light.innerHTML =
      '<svg class="themeModeIcon" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="4"></circle><path d="M12 2.5v2M12 19.5v2M2.5 12h2M19.5 12h2M5.3 5.3l1.4 1.4M17.3 17.3l1.4 1.4M18.7 5.3l-1.4 1.4M6.7 17.3l-1.4 1.4"></path></svg><br>浅色';
  if (dark)
    dark.innerHTML =
      '<svg class="themeModeIcon" viewBox="0 0 24 24" aria-hidden="true"><path d="M19.5 15.2A8 8 0 0 1 8.8 4.5 8 8 0 1 0 19.5 15.2Z"></path></svg><br>深色';
  showVersionInfo = function () {
    closeModal('aboutModal');
    infoTitle.textContent = '版本信息';
    infoText.textContent =
      'OneDay v0.6\n\n本版本更新：\n• 回顾中的每条记录增加独立卡片边界，阅读更清晰\n• 主题设置使用统一线框风格的太阳与月亮图标，日夜模式更易区分';
    openModal('infoModal');
  };
})();
/* v0.6: shared page rhythm, explicit review dividers and task check animation. */
(function () {
  const style = document.createElement('style');
  style.textContent = `
    :root{--page-space:26px;--section-space:24px;--card-space:18px;--title-space:12px}
    .page{padding-bottom:calc(var(--nav-h,86px) + 34px)}
    .page>.top{margin-bottom:var(--page-space)}
    .page .section{margin-top:var(--section-space)}
    .page .sectionHead{margin-bottom:var(--title-space)}
    .page .pageTitle,.page .meIntro h1,.page .reviewHeader h1{margin-bottom:10px}
    .page .sub,.page .meIntro p,.page .reviewHeader p{margin-top:0;margin-bottom:var(--page-space)}
    .page .card,.page .reviewFocusCard,.page .reviewTasksCard,.page .overviewMonth,.page .overviewHero,.page .overviewList,.page .overviewStats{padding:var(--card-space)}
    .reviewFocusCard .reviewSwipeRow{position:relative!important;border:0!important;box-shadow:none!important;border-radius:0!important;background:transparent!important}
    .reviewFocusCard .reviewSwipeRow:not(:last-child){border-bottom:1px solid var(--line)!important;padding-bottom:16px!important;margin-bottom:4px!important}
    .taskCompleteFeedback .check.done{position:relative;color:transparent!important;overflow:visible;animation:check-pop .48s cubic-bezier(.2,1.5,.45,1) both}
    .taskCompleteFeedback .check.done:after{content:'✓';position:absolute;inset:0;display:grid;place-items:center;color:#fff;font-size:18px;font-weight:900;animation:check-draw .48s .08s cubic-bezier(.2,1.5,.45,1) both}
    @keyframes check-pop{0%{transform:scale(.72);background:var(--surface)}55%{transform:scale(1.18)}100%{transform:scale(1)}}
    @keyframes check-draw{0%{opacity:0;transform:scale(.2) rotate(-20deg)}100%{opacity:1;transform:scale(1) rotate(0)}}
  `;
  document.head.append(style);
  showVersionInfo = function () {
    closeModal('aboutModal');
    infoTitle.textContent = '版本信息';
    infoText.textContent =
      'OneDay v0.6\n\n本版本更新：\n• 回顾记录增加清晰的横线分隔\n• 统一各页面的标题、卡片和区块间距规范\n• 今天完成事项时增加勾选绘制动画';
    openModal('infoModal');
  };
})();
/* v0.6: deterministic today check-mark animation after render. */
(function () {
  const style = document.createElement('style');
  style.textContent =
    '.check.checkDraw{position:relative!important;color:transparent!important;overflow:visible!important;animation:checkCirclePulse .52s cubic-bezier(.2,1.45,.45,1) both!important}.check.checkDraw::after{content:"✓"!important;position:absolute!important;inset:0!important;display:grid!important;place-items:center!important;color:#fff!important;font-size:18px!important;font-weight:900!important;line-height:1!important;opacity:0;animation:checkMarkDraw .44s .08s cubic-bezier(.18,1.45,.45,1) forwards!important}@keyframes checkCirclePulse{0%{transform:scale(.55)}60%{transform:scale(1.22)}100%{transform:scale(1)}}@keyframes checkMarkDraw{0%{opacity:0;transform:scale(.1) rotate(-30deg)}100%{opacity:1;transform:scale(1) rotate(0)}}';
  document.head.append(style);
  const baseBindTaskActions = bindTaskActions;
  bindTaskActions = function (root, k) {
    baseBindTaskActions(root, k);
    if (root.id !== 'todayTasks') return;
    root.querySelectorAll('.check').forEach((button) =>
      button.addEventListener('click', () => {
        const id = button.dataset.id;
        setTimeout(() => {
          const fresh = document.querySelector(
            '#todayTasks .check[data-id="' + CSS.escape(id) + '"]',
          );
          if (!fresh || !fresh.classList.contains('done')) return;
          fresh.classList.remove('checkDraw');
          void fresh.offsetWidth;
          fresh.classList.add('checkDraw');
          setTimeout(() => fresh.classList.remove('checkDraw'), 800);
        }, 0);
      }),
    );
  };
  showVersionInfo = function () {
    closeModal('aboutModal');
    infoTitle.textContent = '版本信息';
    infoText.textContent =
      'OneDay v0.6\n\n本版本更新：\n• 修复今天事项完成后未显示勾选动画的问题';
    openModal('infoModal');
  };
})();
/* v0.6: edit note tags in the record editor. */
(function () {
  let editingTags = [];
  const style = document.createElement('style');
  style.textContent =
    '.editTagField{margin-top:14px}.editTagField label{display:block;font-size:13px;color:var(--muted);font-weight:750;margin-bottom:8px}.editTagChoices{display:flex;flex-wrap:wrap;gap:8px}.editTagChoice{border:1px solid var(--line);border-radius:999px;background:var(--surface);color:var(--ink);padding:8px 12px;font:inherit;font-size:13px}.editTagChoice.active{background:var(--accent);border-color:var(--accent);color:#fff}';
  document.head.append(style);
  function availableTags() {
    const custom = Array.isArray(S.settings.customTags) ? S.settings.customTags : [];
    return [...new Set(['日常', '心情', '灵感', ...custom])].slice(0, 24);
  }
  function renderEditTags() {
    const box = document.getElementById('editTagChoices');
    if (!box) return;
    box.innerHTML = availableTags()
      .map(
        (tag) =>
          `<button type="button" class="editTagChoice ${editingTags.includes(tag) ? 'active' : ''}" data-edit-tag="${esc(tag)}">${esc(tag)}</button>`,
      )
      .join('');
    box.querySelectorAll('[data-edit-tag]').forEach(
      (button) =>
        (button.onclick = () => {
          const tag = button.dataset.editTag;
          editingTags = editingTags.includes(tag)
            ? editingTags.filter((x) => x !== tag)
            : [...editingTags, tag];
          renderEditTags();
        }),
    );
  }
  const baseOpenEditReviewEntry = openEditReviewEntry;
  openEditReviewEntry = function (k, i) {
    baseOpenEditReviewEntry(k, i);
    const note = S.notes[k]?.[i];
    if (!note) return;
    editingTags = Array.isArray(note.tags) ? [...note.tags] : [];
    document.querySelector('#noteModal .editTagField')?.remove();
    const field = document.createElement('div');
    field.className = 'editTagField';
    field.innerHTML = '<label>标签</label><div class="editTagChoices" id="editTagChoices"></div>';
    document.getElementById('noteInput')?.closest('.field')?.after(field);
    renderEditTags();
  };
  const baseSaveNote531 = saveNote;
  saveNote = function () {
    if (editingReviewEntry) {
      const note = S.notes[editingReviewEntry.k]?.[editingReviewEntry.i];
      if (note) note.tags = [...editingTags];
    }
    baseSaveNote531();
    editingTags = [];
    document.querySelector('#noteModal .editTagField')?.remove();
  };
  showVersionInfo = function () {
    closeModal('aboutModal');
    infoTitle.textContent = '版本信息';
    infoText.textContent =
      'OneDay v0.6\n\n本版本更新：\n• 编辑回顾记录时可直接添加或取消该记录的标签';
    openModal('infoModal');
  };
})();
/* v0.6: explicit add/remove controls for tags in the record editor. */
(function () {
  let editorTags = [];
  const style = document.createElement('style');
  style.textContent =
    '.recordTagEditor{margin-top:14px}.recordTagEditor label{display:block;font-size:13px;color:var(--muted);font-weight:750;margin:11px 0 7px}.recordTagList{display:flex;flex-wrap:wrap;gap:8px}.recordTagRemove,.recordTagAdd{border:1px solid var(--line);border-radius:999px;background:var(--surface);color:var(--ink);padding:8px 11px;font:inherit;font-size:13px}.recordTagRemove{border-color:color-mix(in srgb,var(--danger) 38%,var(--line));color:var(--danger)}.recordTagAdd{color:var(--accent)}.recordTagAdd:disabled{opacity:.42}.recordTagCustom{display:flex;gap:8px;margin-top:10px}.recordTagCustom input{min-width:0;flex:1;border:1px solid var(--line);border-radius:13px;padding:10px;background:var(--surface);color:var(--ink);font:inherit;font-size:16px}.recordTagCustom button{flex:0 0 auto}';
  document.head.append(style);
  function tagPool() {
    return [
      ...new Set([
        '日常',
        '心情',
        '灵感',
        ...(Array.isArray(S.settings.customTags) ? S.settings.customTags : []),
      ]),
    ].slice(0, 24);
  }
  function renderRecordTagEditor() {
    const box = document.getElementById('recordTagEditor');
    if (!box) return;
    const available = tagPool();
    box.innerHTML = `<label>当前标签</label><div class="recordTagList">${editorTags.length ? editorTags.map((tag) => `<button type="button" class="recordTagRemove" data-remove-record-tag="${esc(tag)}">${esc(tag)} ×</button>`).join('') : '<span class="small">暂未添加标签</span>'}</div><label>添加标签</label><div class="recordTagList">${available.map((tag) => `<button type="button" class="recordTagAdd" data-add-record-tag="${esc(tag)}" ${editorTags.includes(tag) ? 'disabled' : ''}>＋ ${esc(tag)}</button>`).join('')}</div><div class="recordTagCustom"><input id="recordNewTagInput" maxlength="12" placeholder="输入新标签"><button type="button" class="secondary" id="recordNewTagButton">添加</button></div>`;
    box.querySelectorAll('[data-remove-record-tag]').forEach(
      (button) =>
        (button.onclick = () => {
          editorTags = editorTags.filter((tag) => tag !== button.dataset.removeRecordTag);
          renderRecordTagEditor();
        }),
    );
    box.querySelectorAll('[data-add-record-tag]').forEach(
      (button) =>
        (button.onclick = () => {
          const tag = button.dataset.addRecordTag;
          if (!editorTags.includes(tag)) editorTags.push(tag);
          renderRecordTagEditor();
        }),
    );
    box.querySelector('#recordNewTagButton').onclick = () => {
      const input = document.getElementById('recordNewTagInput'),
        tag = input.value.trim().slice(0, 12);
      if (!tag) return;
      if (!Array.isArray(S.settings.customTags)) S.settings.customTags = [];
      if (!S.settings.customTags.includes(tag)) S.settings.customTags.push(tag);
      if (!editorTags.includes(tag)) editorTags.push(tag);
      renderRecordTagEditor();
    };
  }
  const openEditor532 = openEditReviewEntry;
  openEditReviewEntry = function (k, i) {
    openEditor532(k, i);
    const note = S.notes[k]?.[i];
    if (!note) return;
    editorTags = Array.isArray(note.tags) ? [...note.tags] : [];
    document.querySelector('#noteModal .editTagField')?.remove();
    document.querySelector('#noteModal .recordTagEditor')?.remove();
    const host = document.createElement('div');
    host.id = 'recordTagEditor';
    host.className = 'recordTagEditor';
    document.getElementById('noteInput')?.closest('.field')?.after(host);
    renderRecordTagEditor();
  };
  const saveEditor532 = saveNote;
  saveNote = function () {
    const target = editingReviewEntry
      ? S.notes[editingReviewEntry.k]?.[editingReviewEntry.i]
      : null;
    saveEditor532();
    if (target) {
      target.tags = [...editorTags];
      save();
      renderReview();
      renderToday();
      editorTags = [];
    }
  };
  showVersionInfo = function () {
    closeModal('aboutModal');
    infoTitle.textContent = '版本信息';
    infoText.textContent =
      'OneDay v0.6\n\n本版本更新：\n• 编辑记录时可明确添加、移除和新建标签\n• 保存时标签与文字一并更新';
    openModal('infoModal');
  };
})();
/* v0.6: render record tags in every review view. */
(function () {
  const style = document.createElement('style');
  style.textContent =
    '.reviewVisibleTags{display:flex;flex-wrap:wrap;gap:6px;margin-top:10px}.reviewVisibleTag{padding:4px 8px;border-radius:999px;background:color-mix(in srgb,var(--accent) 16%,var(--surface));border:1px solid color-mix(in srgb,var(--accent) 36%,var(--line));color:var(--accent);font-size:12px;font-weight:750}';
  document.head.append(style);
  function tagMarkup(tags) {
    return `<div class="reviewVisibleTags">${tags.map((tag) => `<span class="reviewVisibleTag"># ${esc(tag)}</span>`).join('')}</div>`;
  }
  function renderAllVisibleTags() {
    if (selectedReviewDate) {
      reviewList.querySelectorAll('[data-review-swipe]').forEach((row) => {
        const tags = S.notes[row.dataset.reviewDate]?.[Number(row.dataset.reviewIndex)]?.tags || [],
          entry = row.querySelector('.reviewFocusEntry');
        if (!tags.length || !entry || entry.querySelector('.reviewVisibleTags')) return;
        const text = entry.querySelector('.reviewText');
        (text || entry.querySelector('.reviewEntryHead'))?.insertAdjacentHTML(
          'afterend',
          tagMarkup(tags),
        );
      });
      return;
    }
    reviewList.querySelectorAll('.timelineCard[data-review-date]').forEach((card) => {
      const notes = S.notes[card.dataset.reviewDate] || [],
        tags = [...new Set(notes.flatMap((note) => note.tags || []))];
      if (!tags.length || card.querySelector('.reviewVisibleTags')) return;
      const excerpt = card.querySelector('.timelineExcerpt');
      if (excerpt) excerpt.insertAdjacentHTML('afterend', tagMarkup(tags));
    });
  }
  const baseRenderReview533 = renderReview;
  renderReview = function () {
    baseRenderReview533();
    requestAnimationFrame(renderAllVisibleTags);
  };
  showVersionInfo = function () {
    closeModal('aboutModal');
    infoTitle.textContent = '版本信息';
    infoText.textContent =
      'OneDay v0.6\n\n本版本更新：\n• 修复标签已保存但在回顾中不显示的问题\n• 标签现在同时显示在时间线与单日详情中';
    openModal('infoModal');
  };
})();
/* v0.6: single-source review tag rendering. */
(function () {
  function removeDuplicateReviewTags() {
    document
      .querySelectorAll('.reviewEntryTags,.reviewVisibleTags')
      .forEach((node) => node.remove());
  }
  function addSingleReviewTags() {
    if (selectedReviewDate) {
      reviewList.querySelectorAll('[data-review-swipe]').forEach((row) => {
        const tags = S.notes[row.dataset.reviewDate]?.[Number(row.dataset.reviewIndex)]?.tags || [],
          entry = row.querySelector('.reviewFocusEntry');
        if (!tags.length || !entry) return;
        const host = document.createElement('div');
        host.className = 'reviewVisibleTags';
        host.innerHTML = tags
          .map((tag) => `<span class="reviewVisibleTag"># ${esc(tag)}</span>`)
          .join('');
        const text = entry.querySelector('.reviewText');
        (text || entry.querySelector('.reviewEntryHead'))?.after(host);
      });
      return;
    }
    reviewList.querySelectorAll('.timelineCard[data-review-date]').forEach((card) => {
      const tags = [
          ...new Set((S.notes[card.dataset.reviewDate] || []).flatMap((note) => note.tags || [])),
        ],
        excerpt = card.querySelector('.timelineExcerpt');
      if (tags.length && excerpt)
        excerpt.insertAdjacentHTML(
          'afterend',
          `<div class="reviewVisibleTags">${tags.map((tag) => `<span class="reviewVisibleTag"># ${esc(tag)}</span>`).join('')}</div>`,
        );
    });
  }
  const renderReview534 = renderReview;
  renderReview = function () {
    renderReview534();
    requestAnimationFrame(() => {
      removeDuplicateReviewTags();
      addSingleReviewTags();
    });
  };
  showVersionInfo = function () {
    closeModal('aboutModal');
    infoTitle.textContent = '版本信息';
    infoText.textContent =
      'OneDay v0.6\n\n本版本更新：\n• 修复回顾中同一标签重复显示的问题\n• 每条记录只保留一组高亮标签';
    openModal('infoModal');
  };
})();
/* v0.6: inline highlighted tags immediately after review text. */
(function () {
  const style = document.createElement('style');
  style.textContent =
    '.reviewInlineTag{display:inline-flex;align-items:center;margin-left:8px;vertical-align:middle;padding:3px 8px;border-radius:999px;background:var(--accent)!important;border:1px solid color-mix(in srgb,var(--accent) 70%,#fff)!important;color:#fff!important;font-size:12px!important;font-weight:850!important;line-height:1.2;box-shadow:0 2px 7px color-mix(in srgb,var(--accent) 28%,transparent)}';
  document.head.append(style);
  function renderInlineTags() {
    if (!selectedReviewDate) return;
    document
      .querySelectorAll('.reviewEntryTags,.reviewVisibleTags')
      .forEach((node) => node.remove());
    reviewList.querySelectorAll('[data-review-swipe]').forEach((row) => {
      const note = S.notes[row.dataset.reviewDate]?.[Number(row.dataset.reviewIndex)],
        text = row.querySelector('.reviewText');
      if (!note?.tags?.length || !text) return;
      text.insertAdjacentHTML(
        'beforeend',
        note.tags.map((tag) => `<span class="reviewInlineTag"># ${esc(tag)}</span>`).join(''),
      );
    });
  }
  const renderReview535 = renderReview;
  renderReview = function () {
    renderReview535();
    requestAnimationFrame(renderInlineTags);
  };
  showVersionInfo = function () {
    closeModal('aboutModal');
    infoTitle.textContent = '版本信息';
    infoText.textContent =
      'OneDay v0.6\n\n本版本更新：\n• 回顾标签改为紧跟文字末尾的彩色高亮标记';
    openModal('infoModal');
  };
})();
/* v0.6: direct persistence for tags edited on an existing record. */
(function () {
  const fallbackSaveNote536 = saveNote;
  saveNote = function () {
    if (!editingReviewEntry) return fallbackSaveNote536();
    const { k, i } = editingReviewEntry,
      note = S.notes[k]?.[i],
      text = document.getElementById('noteInput')?.value.trim() || '';
    if (!note) return;
    if (!text && !note.photos?.length) return toast('记录不能是空的');
    const tags = [...document.querySelectorAll('#recordTagEditor [data-remove-record-tag]')]
      .map((button) => button.dataset.removeRecordTag)
      .filter(Boolean);
    note.text = text;
    note.tags = [...new Set(tags)];
    save();
    editingReviewEntry = null;
    const title = document.querySelector('#noteModal h3');
    if (title) title.textContent = '今天有什么值得留下的吗？';
    closeModal('noteModal');
    renderReview();
    renderToday();
    toast('记录和标签已更新');
  };
  showVersionInfo = function () {
    closeModal('aboutModal');
    infoTitle.textContent = '版本信息';
  infoText.textContent =
    'OneDay v0.6\n\n本版本更新：\n• 重构项目文件结构：页面、样式与脚本职责分离\n• 将分散在 HTML 末尾的样式补丁收敛至统一样式表\n• 统一格式化 HTML、CSS 与 JavaScript，提升可读性和可维护性\n• 更新离线缓存清单，离线模式可正确加载样式\n• 新增结构冒烟测试，覆盖资源引用、缓存清单与配置文件校验\n• 修复编辑既有记录时，新增标签未写入记录的问题\n• 保存时直接读取当前标签并更新回顾显示';
    openModal('infoModal');
  };
})();

