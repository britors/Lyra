const pages=[...document.querySelectorAll('[data-page]')];
const steps=[...document.querySelectorAll('.step')];
const back=document.querySelector('#back');
const next=document.querySelector('#next');
const progress=document.querySelector('#progress-bar');
const actionProgress=document.querySelector('.action-progress');
const label=document.querySelector('#step-label');
const finalActions=document.querySelector('#final-actions');
const install=document.querySelector('#install');
const installConfirm=document.querySelector('#install-confirm');
const installConfirmControl=document.querySelector('#install-confirm-control');
const installStatus=document.querySelector('#install-status');
const installStatusTitle=document.querySelector('#install-status-title');
const reboot=document.querySelector('#reboot');
const rebootError=document.querySelector('#reboot-error');
const {invoke}=window.__TAURI__.core;
const {listen}=window.__TAURI__.event;
let current=0;
let storageSnapshot=null;
let selectedDiskPath=null;
let swapChoice='Zram';
let selectedPlan=null;
let summaryConfigValid=false;
let installing=false;
let installationTerminal=false;
let knownScreenSize=`${screen.availWidth}x${screen.availHeight}`;

async function fitWindowToMonitor(){
  try{
    await invoke('fit_window_to_monitor');
  }catch(error){
    console.error('Não foi possível ajustar a janela à área útil do monitor',error);
  }
}

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
  ['ua','Українська','Ucraniano · ЙЦУКЕН','Cirílico','Й Ц У К Е Н І Ї ⌫'],
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

async function loadInstallerLogo(){
  const image=document.querySelector('#brand-logo');
  try{
    const bytes=await invoke('installer_logo');
    let binary='';
    for(let offset=0;offset<bytes.length;offset+=8192){
      binary+=String.fromCharCode(...bytes.slice(offset,offset+8192));
    }
    image.src=`data:image/png;base64,${btoa(binary)}`;
  }catch(error){
    image.alt='Lyra Installer';
    console.error('Não foi possível carregar o logo do instalador',error);
  }
}

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

const transportLabels={Nvme:'NVMe',Sata:'SATA',Virtio:'VirtIO',Usb:'USB',Unknown:'Transporte desconhecido'};

function diskTitle(disk){
  const meaningfulLabel=value=>value&&!/^0x[0-9a-f]+$/i.test(value.trim());
  if(meaningfulLabel(disk.model)) return disk.model.trim();
  if(meaningfulLabel(disk.vendor)) return disk.vendor.trim();

  // VirtIO disks commonly expose only their PCI vendor ID (for example
  // 0x1af4) through lsblk. That identifier is useful to the kernel, not to
  // someone choosing an installation target.
  const transport=disk.transport==='Unknown'&&disk.kname.startsWith('vd')?'Virtio':disk.transport;
  const transportLabel=transportLabels[transport];
  return transportLabel&&transport!=='Unknown'?`Disco ${transportLabel}`:`Disco ${disk.kname}`;
}

function formatBytes(bytes){
  const units=['B','KiB','MiB','GiB','TiB'];
  let value=bytes,i=0;
  while(value>=1024&&i<units.length-1){value/=1024;i++;}
  return `${value.toFixed(i>0&&value<10?1:0)} ${units[i]}`;
}

function diskIneligibleReason(disk){
  if(disk.is_live_media) return 'É a mídia de instalação (live) — não pode ser destino';
  if(disk.role==='RaidMember') return 'Já é membro de um array RAID';
  if(disk.role==='LvmPhysicalVolume') return 'Já é um physical volume LVM em uso';
  return null;
}

function diskStatus(disk){
  const reason=diskIneligibleReason(disk);
  if(reason) return reason;
  if(disk.role==='Unsupported') return 'Partições/dados existentes serão apagados';
  return 'Disponível para instalação';
}

function renderDiskCards(){
  const list=document.querySelector('#disk-list');
  const disks=storageSnapshot?.disks||[];
  if(!disks.length){
    list.innerHTML='<p class="keyboard-empty">Nenhum disco foi encontrado nesta sessão.</p>';
    document.querySelector('#disk-count').textContent='';
    return;
  }
  list.innerHTML=disks.map(disk=>{
      const reason=diskIneligibleReason(disk);
      const title=diskTitle(disk);
      const selected=disk.path===selectedDiskPath;
      return `<label class="disk-card${selected?' selected':''}${reason?' disk-card-disabled':''}">
        <input type="radio" name="disk" value="${disk.path}" ${selected?'checked':''} ${reason?'disabled':''}/>
        <span class="disk-top"><strong>${title}</strong><b>✓</b></span>
        <small>${disk.path} · ${formatBytes(disk.size_bytes)} · ${transportLabels[disk.transport]||disk.transport}</small>
        <span class="disk-status${reason?' disk-status-blocked':''}">${diskStatus(disk)}</span>
      </label>`;
  }).join('');
  document.querySelector('#disk-count').textContent=`${disks.length} disco${disks.length===1?'':'s'} detectado${disks.length===1?'':'s'}`;
}

async function discoverStorage(){
  try{
    storageSnapshot=await invoke('discover_storage');
  }catch(error){
    storageSnapshot=null;
    document.querySelector('#disk-list').innerHTML=`<p class="disk-plan-error">${error}</p>`;
    document.querySelector('#disk-count').textContent='';
    return;
  }
  renderDiskCards();
}

function renderPlan(plan){
  const box=document.querySelector('#disk-plan');
  const esp=plan.esp.Reuse
    ?`ESP existente reaproveitada em ${plan.esp.Reuse.path}`
    :`Nova ESP de ${formatBytes(plan.esp.Create.size_bytes)} será criada`;
  const erased=plan.destructive_summary.erased;
  const swap=plan.swap==='None'
    ?'Sem swap nem ZRAM'
    :(plan.swap==='Zram'?'ZRAM (memória comprimida)':`Swap em disco · ${formatBytes(plan.swap.Partition.size_bytes)}`);
  box.hidden=false;
  box.innerHTML=`
    <div class="plan-row"><span>Partição EFI</span><strong>${esp}</strong></div>
    <div class="plan-row"><span>Sistema de arquivos</span><strong>Btrfs · ${plan.root_filesystem.Btrfs.subvolumes.length} subvolumes</strong></div>
    <div class="plan-row"><span>Memória virtual</span><strong>${swap}</strong></div>
    ${erased.length?`<div class="plan-warning"><strong>Dados que serão apagados nesta instalação:</strong><ul>${erased.map(item=>`<li>${item}</li>`).join('')}</ul></div>`:''}
    ${plan.warnings.length?`<ul class="plan-notes">${plan.warnings.map(item=>`<li>${item}</li>`).join('')}</ul>`:''}
  `;
}

function buildGuidedChoice(){
  if(!selectedDiskPath) return null;
  return {raw_target:{Disk:selectedDiskPath},volume_layer:'Direct',swap:swapChoice};
}

async function refreshPlan(){
  const box=document.querySelector('#disk-plan');
  selectedPlan=null;
  const choice=buildGuidedChoice();
  if(!choice){
    box.hidden=true;
    updateNextButtonState();
    return;
  }
  box.hidden=false;
  box.innerHTML='<p class="keyboard-empty">Calculando o plano de instalação…</p>';
  try{
    selectedPlan=await invoke('plan_install',{snapshot:storageSnapshot,choice});
    renderPlan(selectedPlan);
  }catch(error){
    selectedPlan=null;
    box.innerHTML=`<p class="disk-plan-error">${error}</p>`;
  }
  updateNextButtonState();
}

function updateNextButtonState(){
  const gated=(current===5&&!selectedPlan)||installing||installationTerminal;
  next.disabled=gated;
  next.style.opacity=gated?'.45':'1';
}

function updateInstallButtonState(){
  const enabled=current===6&&selectedPlan&&summaryConfigValid&&installConfirm.checked&&!installing&&!installationTerminal;
  install.disabled=!enabled;
  installConfirm.disabled=installing||installationTerminal||!summaryConfigValid;
  finalActions.hidden=current!==6;
  installConfirmControl.hidden=current!==6||installConfirm.checked||installing||installationTerminal;
  install.hidden=current!==6||!installConfirm.checked||installing||installationTerminal;
}

function show(index){
  current=index;
  pages.forEach((page,i)=>page.classList.toggle('page-active',i===index));
  steps.forEach((step,i)=>step.classList.toggle('active',i===index));
  back.disabled=index===0||installing||installationTerminal;
  back.hidden=index===6&&(installing||installationTerminal);
  next.hidden=index===6;
  actionProgress.hidden=index===6;
  next.innerHTML='Continuar <span>→</span>';
  progress.style.width=`${(index+1)*14.2857}%`;
  label.textContent=`ETAPA 0${index+1} / 07`;
  updateNextButtonState();
  updateInstallButtonState();
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

function suggestedUsername(fullName){
  const normalized=fullName
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g,'')
    .toLocaleLowerCase()
    .replace(/[^a-z0-9]+/g,' ')
    .trim();
  const first=normalized.split(/\s+/)[0]||'';
  return /^[a-z]/.test(first)?first.slice(0,32):'';
}

function collectInstallConfig(){
  return {
    locale: document.querySelector('input[name=locale]:checked').value,
    timezone: document.querySelector('#timezone').value,
    keyboard_layout: document.querySelector('input[name=keyboard]:checked').value,
    hostname: document.querySelector('#hostname').value,
    full_name: document.querySelector('#full-name').value.trim(),
    username: document.querySelector('#username').value,
    password: document.querySelector('#password').value,
  };
}

async function updateSummary(){
  const locale=document.querySelector('input[name=locale]:checked').value;
  const language=languages.find(([value])=>value===locale);
  document.querySelector('#summary-locale').textContent=language?.[1]||locale;
  document.querySelector('#summary-hostname').textContent=document.querySelector('#hostname').value||'lyra-os';
  document.querySelector('#summary-user').textContent=document.querySelector('#username').value||'Aguardando preenchimento';
  const choice=buildGuidedChoice();
  const target=choice?.raw_target?.Disk||'Aguardando seleção';
  document.querySelector('#summary-disk').textContent=target;
  document.querySelector('#summary-swap').textContent=swapChoice==='None'?'Sem swap nem ZRAM':swapChoice==='Disk'?'Swap em disco (8 GiB)':'ZRAM';
  document.querySelector('#install-confirm-text').textContent=`Entendo que os dados de ${target} serão apagados permanentemente.`;
  installConfirm.checked=false;
  install.textContent='Instalar o Lyra OS';
  installStatus.hidden=true;
  installStatus.className='install-status';
  reboot.hidden=true;
  rebootError.hidden=true;

  const validationBox=document.querySelector('#summary-validation');
  summaryConfigValid=false;
  try{
    await invoke('validate_install_config',{config:collectInstallConfig()});
    validationBox.textContent='';
    summaryConfigValid=true;
  }catch(error){
    validationBox.textContent=error;
  }
  updateInstallButtonState();
}

function eventParts(event){
  if(typeof event==='string') return [event,null];
  const entry=Object.entries(event)[0];
  return entry||['Unknown',null];
}

function showExecutionEvent(event){
  const [kind,payload]=eventParts(event);
  let message='O serviço enviou um evento desconhecido';
  if(kind==='Started') message='Serviço privilegiado iniciado';
  else if(kind==='Step') message=payload.detail?`${payload.name}: ${payload.detail}`:payload.name;
  else if(kind==='Warning') message=`Aviso: ${payload.message}`;
  else if(kind==='Failed') message=`Falha em ${payload.step}: ${payload.message}`;
  else if(kind==='Completed') message='Instalação e limpeza concluídas';
  installStatusTitle.textContent=message;
}

function setInstallationStatus(state,title){
  installStatus.hidden=false;
  installStatus.className=`install-status ${state}`;
  installStatusTitle.textContent=title;
}

function lockWizard(locked){
  steps.forEach(step=>{step.disabled=locked;});
  back.disabled=locked||current===0;
}

async function executeInstallation(){
  const choice=buildGuidedChoice();
  if(!choice||!selectedPlan||!summaryConfigValid||!installConfirm.checked||installing||installationTerminal) return;

  installing=true;
  lockWizard(true);
  back.hidden=true;
  reboot.hidden=true;
  rebootError.hidden=true;
  setInstallationStatus('running','Autorizando e iniciando a instalação…');
  updateInstallButtonState();
  updateNextButtonState();

  let stopListening=null;
  const streamedEvents=[];
  try{
    const config=collectInstallConfig();
    await invoke('validate_install_config',{config});
    stopListening=await listen('installation-event',event=>{
      streamedEvents.push(event.payload);
      showExecutionEvent(event.payload);
    });
    const events=await invoke('execute_plan',{request:{choice,plan:selectedPlan,config}});
    // Normally every item has already arrived through the live event. Keep
    // the command response as a fallback if WebKit missed the whole stream or
    // its final items while the privileged process was exiting.
    if(streamedEvents.length!==events.length){
      events.forEach(showExecutionEvent);
    }

    const failure=events.map(eventParts).find(([kind])=>kind==='Failed');
    const completed=events.map(eventParts).some(([kind])=>kind==='Completed');
    if(failure){
      installationTerminal=true;
      const [,payload]=failure;
      setInstallationStatus('failed',`Instalação interrompida em “${payload.step}”`);
      install.textContent='Instalação interrompida';
    }else if(completed){
      installationTerminal=true;
      installStatus.hidden=true;
      reboot.hidden=false;
      await fitWindowToMonitor();
    }else{
      throw new Error('o serviço não informou se a instalação foi concluída');
    }
  }catch(error){
    setInstallationStatus('failed',`Não foi possível iniciar a instalação: ${error}`);
    install.textContent='Tentar instalar novamente';
  }finally{
    if(stopListening) stopListening();
    installing=false;
    lockWizard(installationTerminal);
    back.hidden=installationTerminal;
    updateInstallButtonState();
    updateNextButtonState();
  }
}

async function restartSystem(){
  reboot.disabled=true;
  reboot.textContent='Reiniciando…';
  rebootError.hidden=true;
  try{
    await invoke('restart_system');
  }catch(error){
    reboot.disabled=false;
    reboot.innerHTML='Reiniciar o sistema <span aria-hidden="true">↻</span>';
    rebootError.textContent=`Não foi possível reiniciar o sistema: ${error}`;
    rebootError.hidden=false;
  }
}

next.addEventListener('click',async()=>{if(installing||installationTerminal)return;if(current===4&&!validate())return;if(current===5&&!selectedPlan)return;if(current<6){if(current===5)await updateSummary();show(current+1)}});
back.addEventListener('click',()=>{if(!installing&&!installationTerminal&&current>0)show(current-1)});
steps.forEach(step=>step.addEventListener('click',()=>{const index=Number(step.dataset.step);if(!installing&&!installationTerminal&&index<=current)show(index)}));
installConfirm.addEventListener('change',updateInstallButtonState);
install.addEventListener('click',executeInstallation);
reboot.addEventListener('click',restartSystem);
window.addEventListener('resize',()=>{
  const currentScreenSize=`${screen.availWidth}x${screen.availHeight}`;
  if(currentScreenSize!==knownScreenSize){
    knownScreenSize=currentScreenSize;
    void fitWindowToMonitor();
  }
});
document.querySelectorAll('.choice input').forEach(input=>input.addEventListener('change',()=>{document.querySelectorAll('.choice').forEach(choice=>choice.classList.toggle('selected',choice.querySelector('input').checked))}));
document.querySelector('#keyboard-cards').addEventListener('change',event=>{if(event.target.matches('input'))document.querySelectorAll('.keyboard-card').forEach(card=>card.classList.toggle('selected',card.querySelector('input').checked))});
document.querySelector('#keyboard-search').addEventListener('input',event=>renderKeyboardCards(event.target.value));
document.querySelector('#language-cards').addEventListener('change',event=>{if(event.target.matches('input'))document.querySelectorAll('#language-cards .choice').forEach(card=>card.classList.toggle('selected',card.querySelector('input').checked))});
document.querySelector('#language-search').addEventListener('input',event=>renderLanguageCards(event.target.value));
document.querySelector('#disk-list').addEventListener('change',event=>{
  if(!event.target.matches('input')) return;
  selectedDiskPath=event.target.value;
  renderDiskCards();
  refreshPlan();
});
document.querySelector('#swap-choice').addEventListener('change',event=>{
  if(!event.target.matches('input')) return;
  swapChoice=event.target.value;
  document.querySelectorAll('.swap-card').forEach(card=>card.classList.toggle('selected',card.querySelector('input').checked));
  refreshPlan();
});
let usernameManuallyEdited=false;
document.querySelector('#full-name').addEventListener('input',event=>{
  const username=document.querySelector('#username');
  if(!usernameManuallyEdited) username.value=suggestedUsername(event.target.value);
});
document.querySelector('#username').addEventListener('input',()=>{usernameManuallyEdited=true;});
renderLanguageCards();
renderKeyboardCards();
loadInstallerLogo();
discoverStorage();
show(0);
void fitWindowToMonitor();
