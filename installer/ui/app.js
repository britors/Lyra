const pages=[...document.querySelectorAll('[data-page]')];
const steps=[...document.querySelectorAll('.step')];
const back=document.querySelector('#back');
const next=document.querySelector('#next');
const progress=document.querySelector('#progress-bar');
const label=document.querySelector('#step-label');
let current=0;

const keyboardLayouts=[
  ['br-abnt2','Português (Brasil)','ABNT2 · Português brasileiro','Português','Q W E R T Y Ç ⌫'],
  ['br','Português (Brasil)','Português · variante internacional','Português','Q W E R T Y ´ ⌫'],
  ['pt','Português (Portugal)','Português europeu','Português','Q W E R T Y Ç ⌫'],
  ['us','English (US)','US · padrão ANSI','English','Q W E R T Y [ ⌫'],
  ['us-intl','English (US)','US International · dead keys','English','Q W E R T Y ´ ⌫'],
  ['gb','English (UK)','United Kingdom · ISO','English','Q W E R T Y # ⌫'],
  ['ca','English (Canada)','Canadian Multilingual','English','Q W E R T Y À ⌫'],
  ['ie','English (Ireland)','Irish','English','Q W E R T Y € ⌫'],
  ['es','Español','Espanha · ISO','Europa','Q W E R T Y Ñ ⌫'],
  ['latam','Español (Latinoamérica)','Latin American','América Latina','Q W E R T Y Ñ ⌫'],
  ['fr','Français','AZERTY · França','Europa','A Z E R T Y M ⌫'],
  ['be','Français (Bélgica)','AZERTY · Bélgica','Europa','A Z E R T Y µ ⌫'],
  ['de','Deutsch','QWERTZ · Alemanha','Europa','Q W E R T Z Ü ⌫'],
  ['ch-de','Deutsch (Suíça)','QWERTZ · Suíça','Europa','Q W E R T Z Ä ⌫'],
  ['it','Italiano','Itália · ISO','Europa','Q W E R T Y ò ⌫'],
  ['nl','Nederlands','Holanda · ISO','Europa','Q W E R T Y ë ⌫'],
  ['se','Svenska','Suécia · ISO','Nórdicos','Q W E R T Y Å ⌫'],
  ['no','Norsk','Noruega · ISO','Nórdicos','Q W E R T Y Ø ⌫'],
  ['dk','Dansk','Dinamarca · ISO','Nórdicos','Q W E R T Y Æ ⌫'],
  ['fi','Suomi','Finlândia · ISO','Nórdicos','Q W E R T Y Å ⌫'],
  ['is','Íslenska','Islândia · ISO','Nórdicos','Q W E R T Y Ð ⌫'],
  ['pl','Polski','Polônia · programadores','Europa','Q W E R T Y Ł ⌫'],
  ['cz','Čeština','Tcheco · QWERTZ','Europa','Q W E R T Z Ě ⌫'],
  ['sk','Slovenčina','Eslovaco · QWERTZ','Europa','Q W E R T Z Ľ ⌫'],
  ['hu','Magyar','Húngaro · QWERTZ','Europa','Q W E R T Z Ő ⌫'],
  ['ro','Română','Romênia · standard','Europa','Q W E R T Y Ă ⌫'],
  ['tr','Türkçe','Turquia · QWERTY','Europa','Q W E R T Y Ş ⌫'],
  ['ru','Русский','Russo · ЙЦУКЕН','Cirílico','Й Ц У К Е Н Г Ш ⌫'],
  ['uk','Українська','Ucraniano · ЙЦУКЕН','Cirílico','Й Ц У К Е Н І Ї ⌫'],
  ['bg','Български','Búlgaro · fonético','Cirílico','Я В Е Р Т Ъ У И ⌫'],
  ['el','Ελληνικά','Grego · QWERTY','Cirílico','; ς Ε Ρ Τ Υ Θ ⌫'],
  ['he','עברית','Hebraico · IL','Oriente Médio','/ ק ר א ט י ו ⌫'],
  ['ar','العربية','Árabe · 101','Oriente Médio','ض ص ث ق ف غ ع ه ⌫'],
  ['fa','فارسی','Persa · ISIRI 2901','Oriente Médio','ض ص ث ق ف ع ه خ ⌫'],
  ['ja','日本語','Japonês · JIS','Ásia','Q W E R T Y む ほ ⌫'],
  ['ko','한국어','Coreano · 2-set','Ásia','ㅂ ㅈ ㄷ ㄱ ㅅ ㅛ ㅕ ㅑ ⌫'],
  ['zh-pinyin','中文','Chinês · Pinyin','Ásia','Q W E R T Y U I ⌫'],
  ['th','ไทย','Tailandês · Kedmanee','Ásia','ฟ ห ก ด เ ้ ร า ⌫'],
  ['in','English (India)','Inglês · Índia','Ásia','Q W E R T Y U I ⌫'],
  ['pk','اردو','Urdu · Pakistan','Ásia','ط ظ ذ د ڈ ر ڑ ⌫'],
  ['la','Latina','Latim · clássico','Especial','Q W E R T Y Æ Œ ⌫'],
  ['dvorak','English (US)','Dvorak · ergonômico','Alternativos','\' , . P Y F G C R L ⌫'],
  ['colemak','English (US)','Colemak · ergonômico','Alternativos','Q W F P G J L U Y ; ⌫'],
];

const languages=[
  ['pt_BR.UTF-8','Português (Brasil)','🇧🇷','pt_BR · Recomendado'],['pt_PT.UTF-8','Português (Portugal)','🇵🇹','pt_PT'],['en_US.UTF-8','English (United States)','🇺🇸','en_US'],['en_GB.UTF-8','English (United Kingdom)','🇬🇧','en_GB'],['es_ES.UTF-8','Español (España)','🇪🇸','es_ES'],['es_MX.UTF-8','Español (México)','🇲🇽','es_MX'],['fr_FR.UTF-8','Français','🇫🇷','fr_FR'],['de_DE.UTF-8','Deutsch','🇩🇪','de_DE'],['it_IT.UTF-8','Italiano','🇮🇹','it_IT'],['nl_NL.UTF-8','Nederlands','🇳🇱','nl_NL'],['ca_ES.UTF-8','Català','🏴','ca_ES'],['gl_ES.UTF-8','Galego','🇪🇸','gl_ES'],['eu_ES.UTF-8','Euskara','🇪🇸','eu_ES'],['sv_SE.UTF-8','Svenska','🇸🇪','sv_SE'],['da_DK.UTF-8','Dansk','🇩🇰','da_DK'],['nb_NO.UTF-8','Norsk bokmål','🇳🇴','nb_NO'],['fi_FI.UTF-8','Suomi','🇫🇮','fi_FI'],['is_IS.UTF-8','Íslenska','🇮🇸','is_IS'],['pl_PL.UTF-8','Polski','🇵🇱','pl_PL'],['cs_CZ.UTF-8','Čeština','🇨🇿','cs_CZ'],['sk_SK.UTF-8','Slovenčina','🇸🇰','sk_SK'],['hu_HU.UTF-8','Magyar','🇭🇺','hu_HU'],['ro_RO.UTF-8','Română','🇷🇴','ro_RO'],['tr_TR.UTF-8','Türkçe','🇹🇷','tr_TR'],['ru_RU.UTF-8','Русский','🇷🇺','ru_RU'],['uk_UA.UTF-8','Українська','🇺🇦','uk_UA'],['bg_BG.UTF-8','Български','🇧🇬','bg_BG'],['el_GR.UTF-8','Ελληνικά','🇬🇷','el_GR'],['he_IL.UTF-8','עברית','🇮🇱','he_IL'],['ar_SA.UTF-8','العربية','🇸🇦','ar_SA'],['fa_IR.UTF-8','فارسی','🇮🇷','fa_IR'],['hi_IN.UTF-8','हिन्दी','🇮🇳','hi_IN'],['bn_IN.UTF-8','বাংলা','🇮🇳','bn_IN'],['ja_JP.UTF-8','日本語','🇯🇵','ja_JP'],['ko_KR.UTF-8','한국어','🇰🇷','ko_KR'],['zh_CN.UTF-8','简体中文','🇨🇳','zh_CN'],['zh_TW.UTF-8','繁體中文','🇹🇼','zh_TW'],['th_TH.UTF-8','ไทย','🇹🇭','th_TH'],['vi_VN.UTF-8','Tiếng Việt','🇻🇳','vi_VN'],['id_ID.UTF-8','Bahasa Indonesia','🇮🇩','id_ID'],['ms_MY.UTF-8','Bahasa Melayu','🇲🇾','ms_MY'],['sw_KE.UTF-8','Kiswahili','🇰🇪','sw_KE'],['af_ZA.UTF-8','Afrikaans','🇿🇦','af_ZA'],['la_LA.UTF-8','Latina','🏛️','la_LA']
];

function renderLanguageCards(query=''){
  const normalized=query.trim().toLocaleLowerCase();
  const matches=languages.filter(([,name,,code])=>`${name} ${code}`.toLocaleLowerCase().includes(normalized));
  document.querySelector('#language-cards').innerHTML=matches.map(([value,name,flag,code])=>`<label class="choice${value==='pt_BR.UTF-8'?' selected':''}"><input type="radio" name="locale" value="${value}" ${value==='pt_BR.UTF-8'?'checked':''}/><span class="choice-flag">${flag}</span><span><strong>${name}</strong><small>${code}</small></span><b>✓</b></label>`).join('')||'<p class="keyboard-empty">Nenhum idioma encontrado. Tente outro termo.</p>';
  document.querySelector('#language-count').textContent=`${matches.length} idiomas disponíveis`;
}

function renderKeyboardCards(query=''){
  const normalized=query.trim().toLocaleLowerCase();
  const matches=keyboardLayouts.filter(([,name,variant,group])=>`${name} ${variant} ${group}`.toLocaleLowerCase().includes(normalized));
  const cards=matches.map(([id,name,variant,group,keys])=>`<label class="keyboard-card${id==='br-abnt2'?' selected':''}"><input type="radio" name="keyboard" value="${id}" ${id==='br-abnt2'?'checked':''}/><span class="keyboard-top"><strong>${name}</strong><b>✓</b></span><small>${variant} · ${group}</small><div class="keyboard-layout">${keys.split(' ').map(key=>`<i>${key}</i>`).join('')}</div></label>`).join('');
  document.querySelector('#keyboard-cards').innerHTML=cards||'<p class="keyboard-empty">Nenhum layout encontrado. Tente outro termo.</p>';
  document.querySelector('#keyboard-count').textContent=`${matches.length} layouts disponíveis`;
}

function show(index){
  current=index;
  pages.forEach((page,i)=>page.classList.toggle('page-active',i===index));
  steps.forEach((step,i)=>step.classList.toggle('active',i===index));
  back.disabled=index===0;
  next.innerHTML=index===6?'Backend em desenvolvimento <span>·</span>':'Continuar <span>→</span>';
  next.disabled=index===6;
  next.style.opacity=index===6?'.45':'1';
  progress.style.width=`${(index+1)*14.2857}%`;
  label.textContent=`ETAPA 0${index+1} / 07`;
}

function validate(){
  const errors=[];
  const hostname=document.querySelector('#hostname').value;
  const username=document.querySelector('#username').value;
  const fullName=document.querySelector('#full-name').value.trim();
  const password=document.querySelector('#password').value;
  const confirm=document.querySelector('#password-confirm').value;
  if(!fullName) errors.push('nome completo obrigatório');
  if(!/^[a-z][a-z0-9_-]{0,31}$/.test(username)||username==='root') errors.push('nome de usuário inválido');
  if(!/^[A-Za-z0-9][A-Za-z0-9-]{0,61}[A-Za-z0-9]$/.test(hostname)) errors.push('nome do dispositivo inválido');
  if(password.length<8) errors.push('a senha deve ter ao menos 8 caracteres');
  if(password!==confirm) errors.push('as senhas não coincidem');
  document.querySelector('#validation').textContent=errors.join(' · ');
  return errors.length===0;
}

function updateSummary(){
  const locale=document.querySelector('input[name=locale]:checked').value;
  document.querySelector('#summary-locale').textContent=locale==='pt_BR.UTF-8'?'Português (Brasil)':'English (United States)';
  document.querySelector('#summary-hostname').textContent=document.querySelector('#hostname').value||'lyra-os';
  document.querySelector('#summary-user').textContent=document.querySelector('#username').value||'Aguardando preenchimento';
}

next.addEventListener('click',()=>{if(current===4&&!validate()) return;if(current<6){if(current===5) updateSummary();show(current+1)}});
back.addEventListener('click',()=>{if(current>0)show(current-1)});
steps.forEach(step=>step.addEventListener('click',()=>{const index=Number(step.dataset.step);if(index<=current)show(index)}));
document.querySelectorAll('.choice input').forEach(input=>input.addEventListener('change',()=>{document.querySelectorAll('.choice').forEach(choice=>choice.classList.toggle('selected',choice.querySelector('input').checked))}));
document.querySelector('#keyboard-cards').addEventListener('change',event=>{if(event.target.matches('input'))document.querySelectorAll('.keyboard-card').forEach(card=>card.classList.toggle('selected',card.querySelector('input').checked))});
document.querySelector('#keyboard-search').addEventListener('input',event=>renderKeyboardCards(event.target.value));
document.querySelector('#language-cards').addEventListener('change',event=>{if(event.target.matches('input'))document.querySelectorAll('#language-cards .choice').forEach(card=>card.classList.toggle('selected',card.querySelector('input').checked))});
document.querySelector('#language-search').addEventListener('input',event=>renderLanguageCards(event.target.value));
renderLanguageCards();
renderKeyboardCards();
show(0);
