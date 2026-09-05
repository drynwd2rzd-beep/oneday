const KEY='oneday_app_v3';const colors=['#287052','#386b98','#8057b8','#c75c88','#d77b48','#68717a'];const quotes=['今天不需要改变人生，认真完成一件事就已经很好。','慢一点没关系，方向没有丢就好。','不要追求完美，把真正重要的事往前推一点。','你不需要证明什么，持续行动就够了。','今天的微小完成，会成为以后回头看的证据。','生活不是冲刺，长期走下去比一时用力更重要。','允许普通的一天，也认真过好普通的一天。'];const D=()=>new Date(),pad=n=>String(n).padStart(2,'0'),keyOf=d=>`${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}`,parseDate=s=>{const [y,m,d]=String(s).split('-').map(Number);return new Date(y,m-1,d)};const uuid=()=>crypto?.randomUUID?.()||String(Date.now()+Math.random());
const HOME_MODULE_DEFAULT=['hero','tasks','note','progress','plans'];const HOME_MODULE_META={hero:{title:'问候与日期',desc:'日期、问候和每日一句'},tasks:{title:'今日事项',desc:'查看并完成今天的事项'},note:{title:'值得留下',desc:'快速记录今天真实的想法'},progress:{title:'今日完成情况',desc:'查看当天事项完成进度'},plans:{title:'我的计划',desc:'查看正在进行的长期计划'}};const blankSettings=()=>({theme:'system',accent:'#287052',avatar:'',name:'OneDay',signature:'记录生活，成为更好的自己。',quoteMode:'daily',homeModules:[...HOME_MODULE_DEFAULT]});const blankState=()=>({tasks:[],notes:{},plans:[],settings:blankSettings()});
function normalize(raw){const x=(raw&&typeof raw==='object')?raw:blankState();x.tasks=Array.isArray(x.tasks)?x.tasks.filter(Boolean).map(t=>({id:String(t.id||uuid()),title:String(t.title??t.name??'').trim(),date:typeof t.date==='string'?t.date:keyOf(D()),created:typeof t.created==='string'?t.created:(typeof t.date==='string'?t.date:keyOf(D())),repeat:t.repeat==='daily'?'daily':'once',done:(t.done&&typeof t.done==='object')?t.done:{}})).filter(t=>t.title):[];x.notes=(x.notes&&typeof x.notes==='object'&&!Array.isArray(x.notes))?x.notes:{};Object.keys(x.notes).forEach(k=>{const v=Array.isArray(x.notes[k])?x.notes[k]:[x.notes[k]];x.notes[k]=v.map(n=>typeof n==='string'?{text:n,time:'',photos:[]}:{text:String(n?.text??n?.content??n?.value??'').trim(),time:String(n?.time??''),photos:Array.isArray(n?.photos)?n.photos.filter(x=>typeof x==='string'&&x.startsWith('data:image/')).slice(0,6):[]}).filter(n=>n.text||n.photos?.length);if(!x.notes[k].length)delete x.notes[k]});x.plans=Array.isArray(x.plans)?x.plans.filter(Boolean).map(p=>({id:String(p.id||uuid()),title:String(p.title??p.name??'').trim(),desc:String(p.desc??p.description??''),status:['active','done','archived'].includes(p.status)?p.status:'active',created:typeof p.created==='string'?p.created:keyOf(D())})).filter(p=>p.title):[];x.settings=(x.settings&&typeof x.settings==='object')?x.settings:{};x.settings.theme=['light','dark','system'].includes(x.settings.theme)?x.settings.theme:'system';x.settings.accent=colors.includes(x.settings.accent)?x.settings.accent:colors[0];x.settings.avatar=typeof x.settings.avatar==='string'?x.settings.avatar:'';x.settings.name=String(x.settings.name??'OneDay').trim().slice(0,20)||'OneDay';x.settings.signature=String(x.settings.signature??'记录生活，成为更好的自己。').trim().slice(0,80)||'记录生活，成为更好的自己。';x.settings.quoteMode=x.settings.quoteMode==='static'?'static':'daily';const rawModules=Array.isArray(x.settings.homeModules)?x.settings.homeModules:[...HOME_MODULE_DEFAULT];x.settings.homeModules=rawModules.filter((id,i,a)=>HOME_MODULE_META[id]&&a.indexOf(id)===i);return x}
const UI_SIZE_LABELS={compact:'紧凑',standard:'标准',large:'大'};function currentUiSize(){return UI_SIZE_LABELS[S.settings.uiSize]?S.settings.uiSize:'standard'}function applyUiSize(){const size=currentUiSize();S.settings.uiSize=size;document.documentElement.dataset.uiSize=size;const label=document.getElementById('uiSizeLabel');if(label)label.textContent=UI_SIZE_LABELS[size];document.querySelectorAll('[data-ui-size-choice]').forEach(button=>button.classList.toggle('active',button.dataset.uiSizeChoice===size))}function openUiSize(){applyUiSize();openModal('uiSizeModal')}function saveUiSize(){const selectedSize=document.querySelector('[data-ui-size-choice].active')?.dataset.uiSizeChoice;if(!UI_SIZE_LABELS[selectedSize])return;S.settings.uiSize=selectedSize;applyUiSize();save();closeModal('uiSizeModal');toast('界面大小已保存')}function sanitizeIds(){[...S.tasks,...S.plans].forEach(item=>{const safe=String(item.id||'').replace(/[^A-Za-z0-9_-]/g,'').slice(0,80);item.id=safe||uuid()})}
let appDbPromise=null,appDbReady=false;function openAppDb(){if(!('indexedDB' in window))return Promise.reject(new Error('IndexedDB unavailable'));if(appDbPromise)return appDbPromise;appDbPromise=new Promise((resolve,reject)=>{const request=indexedDB.open('oneday-app',1);request.onupgradeneeded=()=>{if(!request.result.objectStoreNames.contains('state'))request.result.createObjectStore('state')};request.onsuccess=()=>resolve(request.result);request.onerror=()=>reject(request.error||new Error('IndexedDB open failed'))});return appDbPromise}function readDbState(){return openAppDb().then(db=>new Promise((resolve,reject)=>{const request=db.transaction('state','readonly').objectStore('state').get('current');request.onsuccess=()=>resolve(request.result||null);request.onerror=()=>reject(request.error||new Error('IndexedDB read failed'))}))}function writeDbState(value){return openAppDb().then(db=>new Promise((resolve,reject)=>{const request=db.transaction('state','readwrite').objectStore('state').put(value,'current');request.onsuccess=()=>resolve(true);request.onerror=()=>reject(request.error||new Error('IndexedDB write failed'))}))}function initStorage(){readDbState().then(stored=>{if(stored&&typeof stored==='object'){S=normalize(stored);appDbReady=true;applyTheme();applyUiSize();renderToday();renderTasks();renderPlans();renderReview();renderMe()}else{writeDbState(S).then(()=>{appDbReady=true}).catch(error=>console.warn('OneDay IndexedDB migration failed',error))}}).catch(error=>console.warn('OneDay IndexedDB unavailable',error))}function load(){try{return normalize(JSON.parse(localStorage.getItem(KEY)||'null'))}catch{return blankState()}}let S=load(),selected=keyOf(D()),viewMonth=new Date(D().getFullYear(),D().getMonth(),1),reviewMonth=new Date(viewMonth),selectedReviewDate=null,reviewTab='timeline',reviewOverviewMonth=new Date(viewMonth),taskFilter='all',taskTab='today',pendingTheme=S.settings.theme,pendingAccent=S.settings.accent;function save(){sanitizeIds();S=normalize(S);writeDbState(S).then(()=>{appDbReady=true}).catch(error=>console.warn('OneDay IndexedDB save failed',error));try{localStorage.setItem(KEY,JSON.stringify(S));return true}catch(error){console.warn('OneDay localStorage backup unavailable',error);return true}}
function esc(s){return String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}function fmtDate(d){return `${d.getFullYear()}年${d.getMonth()+1}月${d.getDate()}日`}function weekday(d){return ['星期日','星期一','星期二','星期三','星期四','星期五','星期六'][d.getDay()]}function toast(t){const x=document.getElementById('toast');if(!x)return;x.textContent=t;x.classList.add('show');clearTimeout(toast.t);toast.t=setTimeout(()=>x.classList.remove('show'),1700)}function syncModalState(){const hasOpen=document.querySelector('.modal.open');document.body.classList.toggle('modal-open',!!hasOpen);document.body.style.overflow=hasOpen?'hidden':''}function openModal(id){const modal=document.getElementById(id);if(!modal)return;modal.classList.add('open');modal.setAttribute('aria-hidden','false');syncModalState()}function closeModal(id){const modal=document.getElementById(id);if(!modal)return;modal.classList.remove('open');modal.setAttribute('aria-hidden','true');syncModalState()}function applyTheme(){const mode=S.settings.theme;const dark=mode==='dark'||(mode==='system'&&matchMedia('(prefers-color-scheme: dark)').matches);document.documentElement.dataset.theme=dark?'dark':'';document.documentElement.style.setProperty('--green',S.settings.accent);document.documentElement.style.setProperty('--blue',S.settings.accent);const themeMeta=document.querySelector('meta[name="theme-color"]');if(themeMeta)themeMeta.setAttribute('content',dark?'#151a20':'#f5f4ef');document.documentElement.style.colorScheme=dark?'dark':'light'}
function go(id){document.querySelectorAll('.page').forEach(x=>x.classList.toggle('active',x.id===id));document.querySelectorAll('.nav button').forEach(x=>x.classList.toggle('active',x.dataset.go===id));({today:renderToday,tasks:renderTasks,plans:renderPlans,review:renderReview,me:renderMe}[id]||(()=>{}))()}
function installNavHitFix(){
  const nav=document.querySelector('.nav');
  if(!nav)return;
  // v0.488: native document scroll + native button hit testing.
  // No coordinate remapping or document-level touch interception.
  nav.addEventListener('click',e=>{
    const b=e.target.closest('button[data-go]');
    if(!b||!nav.contains(b))return;
    e.preventDefault();
    go(b.dataset.go);
  });
}
installNavHitFix();
document.querySelectorAll('#today .sectionHead .linkBtn').forEach(button=>{
  const text=button.textContent||'';
  button.type='button';
  button.onclick=()=>go(text.includes('计划')?'plans':'tasks');
});
document.querySelectorAll('.modal').forEach(modal=>{
  modal.setAttribute('aria-hidden',modal.classList.contains('open')?'false':'true');
  modal.addEventListener('click',e=>{if(e.target===modal)closeModal(modal.id)});
});
document.querySelectorAll('[data-ui-size-choice]').forEach(button=>button.onclick=()=>{
  const size=button.dataset.uiSizeChoice;
  if(!UI_SIZE_LABELS[size])return;
  document.documentElement.dataset.uiSize=size;
  document.querySelectorAll('[data-ui-size-choice]').forEach(option=>option.classList.toggle('active',option===button));
});
document.querySelector('.aboutVersion')?.replaceChildren('v0.507');
document.querySelectorAll('.settingValue').forEach(value=>{if(value.textContent?.trim()==='v0.489')value.textContent='v0.507'});
window.addEventListener('keydown',e=>{if(e.key==='Escape')document.querySelectorAll('.modal.open').forEach(modal=>closeModal(modal.id))});
function greeting(){const h=D().getHours();return h<11?'早上好。':h<18?'下午好。':'晚上好。'}function taskForDate(t,k){if(t.repeat==='daily')return k>=String(t.created||t.date);return t.date===k}function taskDone(t,k){return !!t.done?.[k]}function setDone(t,k,v){t.done=t.done||{};t.done[k]=v}function completionCount(t){return Object.values(t.done||{}).filter(Boolean).length}
function dayTaskStatus(k){const list=S.tasks.filter(t=>taskForDate(t,k));if(!list.length)return 'none';const done=list.filter(t=>taskDone(t,k)).length;if(!done)return 'none';return done===list.length?'all':'partial'}
function dayStatusDot(k){const status=dayTaskStatus(k);if(status==='all')return '<i class=\"dot\" title=\"当天事项已全部完成\"></i>';if(status==='partial')return '<i class=\"dot partial\" style=\"background:#D7A43C\" title=\"当天事项部分完成\"></i>';return ''}
function taskHTML(t,k){const done=taskDone(t,k);return `<div class="task ${done?'done':''}"><button type="button" class="check ${done?'done':''}" data-id="${esc(t.id)}" aria-label="${done?'取消完成':'完成事项'}：${esc(t.title)}" aria-pressed="${done?'true':'false'}">${done?'✓':''}</button><div style="flex:1"><div class="taskTitle">${esc(t.title)}</div><div class="taskMeta">${t.repeat==='daily'?'每天':'单次'} · 已完成 ${completionCount(t)} 次</div></div><button type="button" class="dots" data-del="${esc(t.id)}" aria-label="删除事项：${esc(t.title)}">⋯</button></div>`}function bindTaskActions(root,k){root.querySelectorAll('.check').forEach(b=>b.onclick=()=>toggleTask(b.dataset.id,k));root.querySelectorAll('[data-del]').forEach(b=>b.onclick=()=>deleteTask(b.dataset.del))}function toggleTask(id,k){const t=S.tasks.find(x=>x.id===id);if(!t)return;const completed=!taskDone(t,k);setDone(t,k,completed);save();renderToday();renderTasks();renderReview();toast(completed?'已完成，进度已更新':'已取消完成')}function deleteTask(id){if(confirm('删除这个事项？')){S.tasks=S.tasks.filter(t=>t.id!==id);save();renderTasks();renderToday();renderReview();toast('已删除')}}
function renderToday(){const d=D(),k=keyOf(d);dateLabel.textContent=`${d.getMonth()+1}月${d.getDate()}日 ${weekday(d)}`;document.getElementById('greeting').textContent=greeting();dailyQuote.textContent=S.settings.quoteMode==='static'?quotes[0]:quotes[Math.floor(d.getTime()/86400000)%quotes.length];const list=S.tasks.filter(t=>taskForDate(t,k)),todo=list.filter(t=>!taskDone(t,k)),done=list.filter(t=>taskDone(t,k));todayTasks.innerHTML=todo.length?todo.map(t=>taskHTML(t,k)).join(''):`<div class="empty">${done.length?'今天的事项已经完成了。':'今天没有待办事项。'}</div>`;bindTaskActions(todayTasks,k);const total=list.length,p=total?Math.round(done.length/total*100):0;progressNum.textContent=p+'%';progressBar.style.width=p+'%';progressDetail.textContent=total?`${done.length}/${total} 已完成`:'从一件小事开始';const activePlans=S.plans.filter(p=>p.status==='active').slice(0,3);const hp=document.getElementById('homePlans');if(hp)hp.innerHTML=activePlans.length?activePlans.map(p=>`<div class="homePlanItem"><div class="homePlanTitle">${esc(p.title)}</div><div class="homePlanDesc">${esc(p.desc||'正在前进。')}</div></div>`).join(''):'<div class="card empty">还没有进行中的计划。</div>';renderHomeModules()}
function renderHomeModules(){const order=S.settings.homeModules||HOME_MODULE_DEFAULT;const page=document.getElementById('today');const top=page.querySelector('.top');const nodes=Object.fromEntries([...page.querySelectorAll('[data-home-module]')].map(n=>[n.dataset.homeModule,n]));order.slice().reverse().forEach(id=>{const n=nodes[id];if(n){n.classList.remove('hidden');page.insertBefore(n,top.nextSibling)}});Object.entries(nodes).forEach(([id,n])=>n.classList.toggle('hidden',!order.includes(id)))}
function openHomeCustomize(){renderHomeCustomize();openModal('homeCustomizeModal')}
function renderHomeCustomize(){const host=document.getElementById('homeCustomizeList');const order=S.settings.homeModules||[...HOME_MODULE_DEFAULT];host.innerHTML=order.map((id,i)=>{const m=HOME_MODULE_META[id];return `<div class="customizeItem"><button class="moduleSwitch on" data-toggle-module="${id}">✓</button><div><div class="moduleTitle">${m.title}</div><div class="moduleDesc">${m.desc}</div></div><div class="moduleMove"><button data-move-module="${id}" data-dir="-1" ${i===0?'disabled':''}>↑</button><button data-move-module="${id}" data-dir="1" ${i===order.length-1?'disabled':''}>↓</button></div></div>`}).join('')+HOME_MODULE_DEFAULT.filter(id=>!order.includes(id)).map(id=>{const m=HOME_MODULE_META[id];return `<div class="customizeItem"><button class="moduleSwitch" data-toggle-module="${id}">✓</button><div><div class="moduleTitle">${m.title}</div><div class="moduleDesc">${m.desc}</div></div><div></div></div>`}).join('');host.querySelectorAll('[data-toggle-module]').forEach(b=>b.onclick=()=>toggleHomeModule(b.dataset.toggleModule));host.querySelectorAll('[data-move-module]').forEach(b=>b.onclick=()=>moveHomeModule(b.dataset.moveModule,Number(b.dataset.dir)))}
function toggleHomeModule(id){let order=[...(S.settings.homeModules||HOME_MODULE_DEFAULT)];order=order.includes(id)?order.filter(x=>x!==id):[...order,id];S.settings.homeModules=order;save();renderHomeModules();renderHomeCustomize()}
function moveHomeModule(id,dir){const order=[...(S.settings.homeModules||HOME_MODULE_DEFAULT)],i=order.indexOf(id),j=i+dir;if(i<0||j<0||j>=order.length)return;[order[i],order[j]]=[order[j],order[i]];S.settings.homeModules=order;save();renderHomeModules();renderHomeCustomize()}
function resetHomeModules(){S.settings.homeModules=[...HOME_MODULE_DEFAULT];save();renderHomeModules();renderHomeCustomize();toast('已恢复首页默认布局')}
function openNote(){noteInput.value='';openModal('noteModal')}function saveNote(){const text=noteInput.value.trim();if(!text)return toast('写一点真实的想法吧');const k=keyOf(D());S.notes[k]=Array.isArray(S.notes[k])?S.notes[k]:[];S.notes[k].push({text,time:new Date().toLocaleTimeString('zh-CN',{hour:'2-digit',minute:'2-digit'})});save();closeModal('noteModal');renderToday();renderReview();toast('已经留下')}
function openTask(){taskInput.value='';taskRepeat.value='once';openModal('taskModal')}function saveTask(){const title=taskInput.value.trim();if(!title)return toast('先写下要做什么');S.tasks.push({id:uuid(),title,date:selected,created:selected,repeat:taskRepeat.value,done:{}});save();closeModal('taskModal');renderTasks();renderToday();toast('已添加')}
function setTaskTab(tab){taskTab=tab;document.querySelectorAll('[data-task-tab]').forEach(b=>b.classList.toggle('active',b.dataset.taskTab===tab));document.querySelectorAll('.taskPanel').forEach(p=>p.classList.toggle('active',p.id==='taskPanel'+tab[0].toUpperCase()+tab.slice(1)))}document.querySelectorAll('[data-task-tab]').forEach(b=>b.onclick=()=>setTaskTab(b.dataset.taskTab));document.querySelectorAll('[data-filter]').forEach(b=>b.onclick=()=>{taskFilter=b.dataset.filter;document.querySelectorAll('[data-filter]').forEach(x=>x.classList.toggle('active',x.dataset.filter===taskFilter));renderTasks()});
function renderTasks(){const all=S.tasks.filter(t=>taskForDate(t,selected)),done=all.filter(t=>taskDone(t,selected)),active=all.filter(t=>!taskDone(t,selected));fAll.textContent=all.length;fActive.textContent=active.length;fDone.textContent=done.length;let show=taskFilter==='all'?all:taskFilter==='active'?active:done;selectedDateTitle.textContent=selected===keyOf(D())?'今天':fmtDate(parseDate(selected));selectedTasks.innerHTML=show.length?show.map(t=>taskHTML(t,selected)).join(''):'<div class="empty">这里还没有事项。</div>';bindTaskActions(selectedTasks,selected);renderCalendar();setTaskTab(taskTab)}
function changeMonth(n){viewMonth.setMonth(viewMonth.getMonth()+n);renderCalendar()}function selectDate(k){selected=k;viewMonth=new Date(parseDate(k).getFullYear(),parseDate(k).getMonth(),1);renderTasks();setTaskTab('today')}function renderCalendar(){const y=viewMonth.getFullYear(),m=viewMonth.getMonth();monthLabel.textContent=`${y}年${m+1}月`;let h='';const first=new Date(y,m,1).getDay(),days=new Date(y,m+1,0).getDate();for(let i=0;i<first;i++)h+='<div></div>';for(let day=1;day<=days;day++){const k=keyOf(new Date(y,m,day));h+=`<button class="day ${k===selected?'selected':''}" data-date="${k}">${day}${dayStatusDot(k)}</button>`}calendarDays.innerHTML=h;calendarDays.querySelectorAll('[data-date]').forEach(b=>b.onclick=()=>{selected=b.dataset.date;renderCalendar();renderTasks();setTaskTab('calendar')});calendarDateTitle.textContent=fmtDate(parseDate(selected))+' '+weekday(parseDate(selected));const list=S.tasks.filter(t=>taskForDate(t,selected));calendarTasks.innerHTML=list.length?list.map(t=>taskHTML(t,selected)).join(''):'<div class="empty">这一天没有事项。</div>';bindTaskActions(calendarTasks,selected)}
let editingPlanId=null;function openPlan(){editingPlanId=null;planTitle.value='';planDesc.value='';planModalTitle.textContent='新的计划';openModal('planModal')}function editPlan(id){const p=S.plans.find(x=>x.id===id);if(!p)return;editingPlanId=id;planTitle.value=p.title||'';planDesc.value=p.desc||'';planModalTitle.textContent='编辑计划';openModal('planModal')}function savePlan(){const title=planTitle.value.trim();if(!title)return toast('计划需要一个名字');const desc=planDesc.value.trim();if(editingPlanId){const p=S.plans.find(x=>x.id===editingPlanId);if(!p)return;p.title=title;p.desc=desc;save();editingPlanId=null;closeModal('planModal');renderPlans();renderToday();toast('计划已更新');return}S.plans.push({id:uuid(),title,desc,status:'active',created:keyOf(D())});save();closeModal('planModal');renderPlans();toast('已添加计划')}function planCard(p){const status=p.status==='active'?'进行中':p.status==='done'?'已完成':'已归档';return `<div class="card planCard"><div class="small">${status}</div><h2>${esc(p.title)}</h2><div class="empty">${esc(p.desc||'没有额外说明。')}</div><div class="planStatus">${p.status==='active'?'正在前进':p.status==='done'?'已经完成':'暂时归档'}</div><div class="planActions"><button class="secondary" onclick="editPlan('${p.id}')">编辑</button>${p.status==='active'?`<button class="secondary" onclick="planStatus('${p.id}','done')">完成</button><button class="secondary" onclick="planStatus('${p.id}','archived')">归档</button>`:`<button class="secondary" onclick="planStatus('${p.id}','active')">重新进行</button>`}<button class="secondary danger" onclick="deletePlan('${p.id}')">删除</button></div></div>`}function renderPlans(){const a=S.plans.filter(p=>p.status==='active'),d=S.plans.filter(p=>p.status==='done'),r=S.plans.filter(p=>p.status==='archived');plansList.innerHTML=(a.length?a.map(planCard).join(''):'<div class="card empty">还没有进行中的计划。先写下真正重要的方向。</div>')+collapseSection('donePlans','已完成',d)+collapseSection('archivedPlans','已归档',r)}function collapseSection(id,title,items){return `<div class="collapseBox"><button class="collapseHead" onclick="toggleCollapse('${id}')"><span>${title}</span><span>${items.length} 个 ›</span></button><div class="collapseBody" id="${id}">${items.map(planCard).join('')}</div></div>`}function toggleCollapse(id){document.getElementById(id)?.classList.toggle('open')}function planStatus(id,status){const p=S.plans.find(x=>x.id===id);if(!p)return;p.status=status;save();renderPlans();toast('已更新计划状态')}function deletePlan(id){if(confirm('删除这个计划？')){S.plans=S.plans.filter(x=>x.id!==id);save();renderPlans();toast('已删除')}}
let pendingQuickPhotos=[];function handleQuickPhotos(files){const list=[...(files||[])].filter(f=>f.type?.startsWith('image/')).slice(0,6-pendingQuickPhotos.length);if(!list.length)return;if(list.length<(files||[]).length&&pendingQuickPhotos.length>=6)toast('最多添加 6 张照片');Promise.all(list.map(compressImage)).then(arr=>{pendingQuickPhotos.push(...arr.filter(Boolean));renderQuickPhotoPreview()}).catch(()=>toast('照片读取失败'))}function compressImage(file){return new Promise((resolve,reject)=>{const r=new FileReader();r.onload=()=>{const img=new Image();img.onload=()=>{let w=img.naturalWidth,h=img.naturalHeight,max=1280;if(Math.max(w,h)>max){const q=max/Math.max(w,h);w=Math.round(w*q);h=Math.round(h*q)}const c=document.createElement('canvas');c.width=w;c.height=h;const ctx=c.getContext('2d');ctx.drawImage(img,0,0,w,h);resolve(c.toDataURL('image/jpeg',.82))};img.onerror=reject;img.src=r.result};r.onerror=reject;r.readAsDataURL(file)})}function renderQuickPhotoPreview(){const box=document.getElementById('quickPhotoPreview');if(!box)return;box.innerHTML=pendingQuickPhotos.map((src,i)=>`<div class="quickPhotoItem"><img src="${src}" alt="照片 ${i+1}"><button class="quickPhotoRemove" type="button" onclick="removeQuickPhoto(${i})">×</button></div>`).join('')}function removeQuickPhoto(i){pendingQuickPhotos.splice(i,1);renderQuickPhotoPreview()}function saveQuickNote(){const input=document.getElementById('quickNoteInput'),text=input?.value.trim()||'';if(!text&&!pendingQuickPhotos.length)return toast('写一点内容，或者留下一张照片');const k=keyOf(D()),time=`${pad(D().getHours())}:${pad(D().getMinutes())}`;S.notes[k]=S.notes[k]||[];S.notes[k].push({text,time,photos:[...pendingQuickPhotos]});save();input.value='';pendingQuickPhotos=[];const photoInput=document.getElementById('quickPhotoInput');if(photoInput)photoInput.value='';renderQuickPhotoPreview();renderReview();renderToday();toast('已经留下来了')}
function recordDates(){
  // 回顾日期只来源于文字记录；事项完成状态不参与回顾日历或时间线。
  return Object.keys(S.notes).filter(k=>Array.isArray(S.notes[k])&&S.notes[k].length>0).sort((a,b)=>b.localeCompare(a));
}
function reviewTasks(k){return S.tasks.filter(t=>taskForDate(t,k))}
function reviewMarkers(k){
  // 右上角标记只代表“值得留下”的文字记录，不参与事项完成状态。
  // 有记录显示一个实心点；没有记录不显示点，避免与任务完成混淆。
  const hasNote=Array.isArray(S.notes[k])&&S.notes[k].length>0;
  return hasNote?'<span class="reviewMarker done note" title="有文字记录"></span>':'';
}
function monthKey(k){const d=parseDate(k);return `${d.getFullYear()}年${d.getMonth()+1}月`}
function reviewExcerpt(notes){
  return notes?.length?(notes[0].text?esc(notes[0].text).replace(/\n+/g,' '):(notes[0].photos?.length?'留下了照片':'')):'';
}
function setReviewTab(tab){reviewTab=tab;selectedReviewDate=null;renderReview()}
function changeOverviewMonth(n){reviewOverviewMonth=new Date(reviewOverviewMonth.getFullYear(),reviewOverviewMonth.getMonth()+n,1);renderReview()}
function monthBounds(d){return {start:keyOf(new Date(d.getFullYear(),d.getMonth(),1)),end:keyOf(new Date(d.getFullYear(),d.getMonth()+1,0))}}
function monthlyOverview(month){
  const {start,end}=monthBounds(month);
  const items=S.tasks.map(t=>{let count=0;Object.entries(t.done||{}).forEach(([k,v])=>{if(v&&k>=start&&k<=end)count++});return {title:t.title,count}}).filter(x=>x.count>0).sort((a,b)=>b.count-a.count||a.title.localeCompare(b.title,'zh-CN'));
  const total=items.reduce((n,x)=>n+x.count,0);
  const noteDays=Object.entries(S.notes).filter(([k,v])=>k>=start&&k<=end&&v?.length).length;
  const active=new Set();Object.entries(S.notes).forEach(([k,v])=>{if(k>=start&&k<=end&&v?.length)active.add(k)});S.tasks.forEach(t=>Object.entries(t.done||{}).forEach(([k,v])=>{if(v&&k>=start&&k<=end)active.add(k)}));
  return {items,total,noteDays,activeDays:active.size};
}
function renderReviewOverview(){
  const data=monthlyOverview(reviewOverviewMonth),label=`${reviewOverviewMonth.getFullYear()}年${reviewOverviewMonth.getMonth()+1}月`,max=Math.max(1,...data.items.map(x=>x.count));
  reviewList.innerHTML=`<div class="overviewMonth"><button aria-label="上个月" onclick="changeOverviewMonth(-1)">‹</button><strong>${label}</strong><button aria-label="下个月" onclick="changeOverviewMonth(1)">›</button></div><section class="overviewHero"><div class="overviewHeroLabel">本月完成事项</div><div class="overviewHeroRow"><div class="overviewHeroNum">${data.total}<span>次</span></div><div class="overviewHeroSub">每一次完成，都是<br>真实发生过的一天。</div></div></section><section class="overviewList"><div class="overviewListHead"><span>各事项完成次数</span><span class="small">${data.items.length?`${data.items.length} 个事项`:'暂无数据'}</span></div>${data.items.length?data.items.map(x=>`<div class="overviewItem"><div class="overviewItemName">${esc(x.title)}</div><div class="overviewItemCount">${x.count} 次</div><div class="overviewBar"><i style="width:${Math.max(8,Math.round(x.count/max*100))}%"></i></div></div>`).join(''):'<div class="overviewEmpty">这个月还没有完成记录。<br>完成一次事项后，这里会自动出现。</div>'}</section><section class="overviewStats"><div class="overviewStat"><span>完成次数</span><strong>${data.total}</strong></div><div class="overviewStat"><span>有文字记录</span><strong>${data.noteDays} 天</strong></div><div class="overviewStat"><span>活跃天数</span><strong>${data.activeDays} 天</strong></div></section>`;
}
function renderReviewTimeline(){
  const list=selectedReviewDate?[selectedReviewDate]:recordDates();
  if(selectedReviewDate){
    const k=selectedReviewDate,d=parseDate(k),notes=S.notes[k]||[],tasks=reviewTasks(k);
    reviewList.innerHTML=`<div class="reviewDayHero"><div class="reviewDayLabel">${fmtDate(d)} · ${weekday(d)}</div><div class="reviewDayTitle">那一天</div><div class="reviewDaySub">回到这一天，看看留下了什么。</div></div>${notes.length?`<section class="reviewFocusCard">${notes.map((n,i)=>`<div class="reviewSwipeRow" data-review-swipe data-review-date="${k}" data-review-index="${i}"><div class="reviewSwipeDelete">删除</div><div class="reviewFocusEntry"><div class="reviewEntryHead"><div class="reviewEntryMeta">${n.time?esc(n.time):`记录 ${i+1}`}</div></div>${n.text?`<div class="reviewText">${esc(n.text)}</div>`:''}${n.photos?.length?`<div class="reviewPhotos">${n.photos.map((src,j)=>`<img class="reviewPhoto" src="${src}" alt="记录照片 ${j+1}" loading="lazy" onclick="openPhotoPreview(this.src)">`).join('')}</div>`:''}</div></div>`).join('')}</section>`:''}<section class="reviewTasksCard"><div class="reviewTasksHead">那一天的事项</div>${tasks.length?tasks.map(t=>`<div class="reviewTaskRow"><span class="reviewCheck ${taskDone(t,k)?'done':''}">${taskDone(t,k)?'✓':''}</span><span>${esc(t.title)}</span></div>`).join(''):'<div class="reviewQuiet">这一天没有安排事项。</div>'}</section><div class="reviewDayActions">${notes.length?`<button class="secondary danger reviewDeleteAllBtn" type="button" onclick="deleteReviewDay('${k}')">删除全部记录</button>`:''}<button class="reviewTimelineBtn" type="button" onclick="clearReviewDate()">查看时间线 <span>→</span></button></div>`;bindReviewEntrySwipe(reviewList);return;
  }
  if(!list.length){reviewList.innerHTML='<div class="card empty">开始留下文字记录后，这里会慢慢长出属于你的时间线。</div>';return}
  let lastMonth='';reviewList.innerHTML=list.map(k=>{const d=parseDate(k),notes=S.notes[k]||[],mk=monthKey(k),month=mk!==lastMonth?`<div class="reviewMonthDivider">${mk}</div>`:'';lastMonth=mk;const done=reviewTasks(k).filter(t=>taskDone(t,k)).length,hasNote=notes.length>0;return `${month}<button class="timelineCard" data-review-date="${k}"><div class="timelineMain"><div class="timelineDate"><strong>${d.getMonth()+1}月${d.getDate()}日</strong><span>${weekday(d)}</span></div><div class="timelineExcerpt">${reviewExcerpt(notes)}</div><div class="timelineMeta">${hasNote?'<span>有记录</span>':''}${done?`<span>完成了 ${done} 件事项</span>`:''}</div></div><div class="timelineSide"><div class="reviewMarkers">${reviewMarkers(k)}</div><span class="timelineArrow">›</span></div></button>`}).join('');
  reviewList.querySelectorAll('[data-review-date]').forEach(b=>b.onclick=()=>{selectedReviewDate=b.dataset.reviewDate;renderReview();window.scrollTo?.({top:0,behavior:'smooth'})});
}
function renderReview(){document.getElementById('reviewTabTimeline')?.classList.toggle('active',reviewTab==='timeline');document.getElementById('reviewTabOverview')?.classList.toggle('active',reviewTab==='overview');if(reviewTab==='overview'){renderReviewOverview();return}renderReviewTimeline()}
function bindReviewEntrySwipe(root){
  root.querySelectorAll('[data-review-swipe]').forEach(row=>{
    const card=row.querySelector('.reviewFocusEntry'),action=row.querySelector('.reviewSwipeDelete');
    if(!card||!action)return;
    let startX=0,startY=0,current=0,dragging=false,horizontal=false,open=false;
    const max=72;
    const setX=(x,animate=false)=>{row.classList.toggle('swiped',x<0);card.style.transition=animate?'transform .2s ease':'';card.style.transform=`translateX(${x}px)`;current=x;};
    const close=()=>{open=false;setX(0,true)};
    action.setAttribute('role','button');action.setAttribute('tabindex','0');action.setAttribute('aria-label','删除这条记录');
    card.addEventListener('touchstart',e=>{startX=e.touches[0].clientX;startY=e.touches[0].clientY;dragging=true;horizontal=false;card.style.transition='none'},{passive:true});
    card.addEventListener('touchmove',e=>{
      if(!dragging)return;
      const dx=e.touches[0].clientX-startX;
      const dy=e.touches[0].clientY-startY;
      if(!horizontal){if(Math.abs(dy)>Math.abs(dx)+6){dragging=false;return}if(Math.abs(dx)<8)return;horizontal=true}
      e.preventDefault();
      const x=Math.max(-max,Math.min(0,(open?-max:0)+dx));
      setX(x,false);
    },{passive:false});
    card.addEventListener('touchend',()=>{if(!dragging)return;dragging=false;if(!horizontal)return;open=current<-34;setX(open?-max:0,true)});
    card.addEventListener('touchcancel',()=>{dragging=false;close()});
    action.onclick=()=>deleteReviewEntry(row.dataset.reviewDate,Number(row.dataset.reviewIndex));
    action.onkeydown=e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();action.click()}};
    row.addEventListener('click',e=>{if(open&&!action.contains(e.target)){e.preventDefault();close()}});
  });
}
function deleteReviewEntry(k,i){const notes=S.notes[k];if(!Array.isArray(notes)||!notes[i])return;if(!confirm('删除这条记录？'))return;notes.splice(i,1);if(!notes.length)delete S.notes[k];save();if(!S.notes[k]?.length)selectedReviewDate=null;renderReview();renderToday();toast('已删除这条记录')}function deleteReviewDay(k){const d=parseDate(k);if(!confirm(`删除 ${fmtDate(d)} 的全部记录？\n\n这只会删除当天留下的文字和照片，不会影响事项完成状态。`))return;delete S.notes[k];save();if(selectedReviewDate===k)selectedReviewDate=null;renderReview();renderToday();toast('已删除全部记录')}
function clearReviewDate(){selectedReviewDate=null;reviewTab='timeline';renderReview()}
function openReviewCalendar(){reviewMonth=selectedReviewDate?new Date(parseDate(selectedReviewDate).getFullYear(),parseDate(selectedReviewDate).getMonth(),1):new Date(D().getFullYear(),D().getMonth(),1);renderReviewCalendar();openModal('reviewCalModal')}
function changeReviewMonth(n){reviewMonth.setMonth(reviewMonth.getMonth()+n);renderReviewCalendar()}
function renderReviewCalendar(){
  const y=reviewMonth.getFullYear(),m=reviewMonth.getMonth();reviewMonthLabel.textContent=`${y}年${m+1}月`;
  let h='';const first=new Date(y,m,1).getDay(),days=new Date(y,m+1,0).getDate();
  for(let i=0;i<first;i++)h+='<div></div>';
  for(let day=1;day<=days;day++){
    const k=keyOf(new Date(y,m,day)),hasNote=recordDates().includes(k);
    // 回顾日历只显示文字/照片记录的绿色点，绝不复用事项的完成状态点。
    h+=`<button class="day ${k===selectedReviewDate?'selected':''}" data-rdate="${k}">${day}${hasNote?'<i class=\"dot note\" title=\"有记录\"></i>':''}</button>`;
  }
  reviewCalendarDays.innerHTML=h;
  reviewCalendarDays.querySelectorAll('[data-rdate]').forEach(b=>b.onclick=()=>{selectedReviewDate=b.dataset.rdate;closeModal('reviewCalModal');renderReview()});
}
function meDoneCount(){return S.tasks.reduce((n,t)=>n+Object.values(t.done||{}).filter(Boolean).length,0)}
function meNoteCount(){return Object.values(S.notes).reduce((n,v)=>n+(Array.isArray(v)?v.length:0),0)}
function avatarFallback(){return 'data:image/svg+xml;charset=UTF-8,'+encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="140" height="140" viewBox="0 0 140 140"><rect width="140" height="140" fill="%2320262e"/><circle cx="70" cy="52" r="24" fill="%236b7682"/><path d="M28 128c5-30 23-45 42-45s37 15 42 45" fill="%236b7682"/></svg>')}
function renderMe(){
  applyUiSize();
  const fallback=avatarFallback(),src=S.settings.avatar||fallback;
  const a=document.getElementById('avatarImg'),preview=document.getElementById('profileAvatarPreview');
  if(a)a.src=src;if(preview)preview.src=src;
  const name=S.settings.name||'OneDay',sig=S.settings.signature||'记录生活，成为更好的自己。';
  document.getElementById('meProfileName')&&(document.getElementById('meProfileName').textContent=name);
  document.getElementById('meProfileSub')&&(document.getElementById('meProfileSub').textContent=sig);
  document.getElementById('meStatDays')&&(document.getElementById('meStatDays').textContent=recordDates().length);
  document.getElementById('meStatNotes')&&(document.getElementById('meStatNotes').textContent=meNoteCount());
  document.getElementById('meStatDone')&&(document.getElementById('meStatDone').textContent=meDoneCount());
  const tl=document.getElementById('themeLabel');if(tl)tl.textContent=S.settings.theme==='light'?'浅色':S.settings.theme==='dark'?'深色':'跟随系统';
}
function openProfile(){
  document.getElementById('profileNameInput').value=S.settings.name||'OneDay';
  document.getElementById('profileSignatureInput').value=S.settings.signature||'记录生活，成为更好的自己。';
  document.getElementById('profileAvatarPreview').src=S.settings.avatar||avatarFallback();
  openModal('profileModal');
}
function saveProfile(){
  const name=document.getElementById('profileNameInput').value.trim().slice(0,20)||'OneDay';
  const signature=document.getElementById('profileSignatureInput').value.trim().slice(0,80)||'记录生活，成为更好的自己。';
  S.settings.name=name;S.settings.signature=signature;save();renderMe();closeModal('profileModal');toast('个人资料已保存');
}
function openDataManage(){openModal('dataManageModal')}
function openAboutPage(){openModal('aboutModal')}
function showVersionInfo(){closeModal('aboutModal');infoTitle.textContent='版本信息';infoText.textContent='OneDay v0.507\n\n本版本更新：\n• 清理重复覆盖代码，统一计划编辑、版本信息和初始化逻辑\n• 移除不存在的图标引用，避免 GitHub Pages 产生 404 请求\n• 移除无效的界面大小快捷引用\n• 底栏五个图标统一为同一套细线几何风格\n• 计划支持编辑已有的名称和说明，不改变完成状态与创建日期\n• 完成事项增加明确的完成反馈、进度更新提示和无障碍状态\n• 支持 IndexedDB 自动保存、JSON 导入导出和 GitHub Pages 离线缓存';openModal('infoModal')}
avatarInput.onchange=e=>{const f=e.target.files?.[0];e.target.value='';if(!f)return;if(f.size>4*1024*1024)return toast('图片请小于 4MB');const r=new FileReader();r.onload=()=>{S.settings.avatar=String(r.result);save();renderMe();document.getElementById('profileAvatarPreview')&&(document.getElementById('profileAvatarPreview').src=S.settings.avatar);toast('头像已更换')};r.readAsDataURL(f)}
function openTheme(){pendingTheme=S.settings.theme;pendingAccent=S.settings.accent;renderThemeChoices();openModal('themeModal')}function renderThemeChoices(){document.querySelectorAll('[data-theme-choice]').forEach(b=>b.classList.toggle('active',b.dataset.themeChoice===pendingTheme));colorChoices.innerHTML=colors.map(c=>`<button class="colorDot ${c===pendingAccent?'active':''}" data-color="${c}" style="background:${c}"></button>`).join('');document.querySelectorAll('[data-theme-choice]').forEach(b=>b.onclick=()=>{pendingTheme=b.dataset.themeChoice;renderThemeChoices()});colorChoices.querySelectorAll('[data-color]').forEach(b=>b.onclick=()=>{pendingAccent=b.dataset.color;renderThemeChoices()})}function saveTheme(){S.settings.theme=pendingTheme;S.settings.accent=pendingAccent;save();applyTheme();renderMe();closeModal('themeModal');toast('主题已保存')}
function exportData(){const a=document.createElement('a'),u=URL.createObjectURL(new Blob([JSON.stringify(S,null,2)],{type:'application/json'}));a.href=u;a.download='oneday-backup.json';a.click();setTimeout(()=>URL.revokeObjectURL(u),800);toast('数据已导出')}
importInput.onchange=e=>{const f=e.target.files?.[0];e.target.value='';if(!f)return;if(f.size>10*1024*1024)return toast('备份文件不能超过 10MB');const r=new FileReader();r.onload=()=>{try{const raw=JSON.parse(String(r.result||''));if(!raw||typeof raw!=='object')throw new Error('invalid');const incoming=normalize(raw);if(!confirm('导入会替换当前设备中的 OneDay 数据，建议先导出备份。确定继续吗？'))return;S=incoming;save();applyTheme();renderToday();renderTasks();renderPlans();renderReview();renderMe();toast('数据已导入')}catch{toast('无法识别这个备份文件')}};r.onerror=()=>toast('读取备份失败');r.readAsText(f,'utf-8')}
let restoreReturnToDataManage=false;function openRestore(){restoreReturnToDataManage=false;openModal('restoreModal')}function openRestoreFromDataManage(){restoreReturnToDataManage=true;closeModal('dataManageModal');openModal('restoreModal')}function cancelRestore(){closeModal('restoreModal');if(restoreReturnToDataManage){restoreReturnToDataManage=false;openModal('dataManageModal')}}function restoreAllData(){if(!confirm('确定恢复初始设置吗？这会清除头像、主题、事项、计划、回顾记录、完成历史和统计数据，且无法撤销。'))return;if(!confirm('请再次确认：所有 OneDay 数据都会被清空。确定恢复到初始状态吗？'))return;S=blankState();selected=keyOf(D());viewMonth=new Date(D().getFullYear(),D().getMonth(),1);reviewMonth=new Date(viewMonth);selectedReviewDate=null;reviewTab='timeline';reviewOverviewMonth=new Date(viewMonth);taskFilter='all';taskTab='today';pendingTheme=S.settings.theme;pendingAccent=S.settings.accent;save();applyTheme();restoreReturnToDataManage=false;closeModal('restoreModal');renderToday();renderTasks();renderPlans();renderReview();renderMe();toast('已恢复初始状态')}function openHelp(){infoTitle.textContent='使用说明';infoText.textContent='今天：记录当天的想法并完成事项。\n事项：查看今日、日历和完成统计。\n计划：管理长期方向，可完成或归档。\n回顾：只回看真实记录，不把人生变成任务成绩单。';openModal('infoModal')}function openAbout(){infoTitle.textContent='OneDay';infoText.textContent='记录生活，成为更好的自己。\n\nOneDay v0.490';openModal('infoModal')}

function openPhotoPreview(src){
  const box=document.getElementById('photoLightbox');
  const img=document.getElementById('photoLightboxImage');
  if(!box||!img||!src)return;
  img.src=src;
  box.classList.add('open');
  box.setAttribute('aria-hidden','false');
  document.body.style.overflow='hidden';
}
function closePhotoPreview(){
  const box=document.getElementById('photoLightbox');
  const img=document.getElementById('photoLightboxImage');
  if(!box)return;
  box.classList.remove('open');
  box.setAttribute('aria-hidden','true');
  document.body.style.overflow='';
  setTimeout(()=>{if(!box.classList.contains('open')&&img)img.removeAttribute('src')},180);
}

/* v0.489: review owns all completion aggregation; individual/all record deletion; floating iOS nav island. */
function syncNavHeight(){
  const nav=document.querySelector('.nav');
  if(!nav)return;
  document.documentElement.style.setProperty('--nav-h',Math.ceil(nav.getBoundingClientRect().height||86)+'px');
}
function syncViewportHeight(){const height=Math.round(window.visualViewport?.height||window.innerHeight||0);if(height)document.documentElement.style.setProperty('--viewport-height',`${height}px`)}
function scheduleNavSync(){requestAnimationFrame(()=>requestAnimationFrame(()=>{syncNavHeight();syncViewportHeight()}));}
window.addEventListener('pageshow',scheduleNavSync,{passive:true});
window.addEventListener('resize',scheduleNavSync,{passive:true});
window.addEventListener('orientationchange',scheduleNavSync,{passive:true});
window.visualViewport?.addEventListener('resize',scheduleNavSync,{passive:true});
window.visualViewport?.addEventListener('scroll',scheduleNavSync,{passive:true});
document.documentElement.classList.add('oneday-v0488');applyTheme();applyUiSize();save();renderToday();renderTasks();renderPlans();renderReview();renderMe();scheduleNavSync();initStorage();
if('serviceWorker' in navigator&&location.protocol!=='file:'){navigator.serviceWorker.register('./service-worker.js').catch(error=>console.warn('OneDay service worker unavailable',error))}
