// Installer UI translations. Add a locale by registering one catalog here;
// missing keys always fall back to en-US so partial future translations do
// not leave blank controls or expose implementation keys to the user.
window.LyraI18n=(()=>{
  const catalogs={
    'en-US':{
      title:'Install Lyra OS',back:'← Back',next:'Continue <span>→</span>',step:'STEP {current} / 07',
      languageCount:'{count} languages available',noLanguages:'No languages found. Try another search.',
      keyboardCount:'{count} layouts available',noKeyboards:'No layouts found. Try another search.',
      diskCount:'{count} disk{s} detected',noDisks:'No disks were found in this session.',detectingDisks:'Detecting disks…',
      waitingInput:'Waiting for input',waitingSelection:'Waiting for selection',unknownTransport:'Unknown transport',
      installAuthorizing:'Authorizing and starting the installation…',installStarted:'Preparing the installation…',installing:'Installing Lyra OS…',
      installWarning:'The installer reported a warning',installFailed:'The installation was interrupted',installCompleted:'Installation and cleanup completed',installRetry:'Try installing again',
      static:{
        '.rail-footer':'<span class="status-dot"></span> Secure live session',
        '.step[data-step="0"]':'<span>01</span> Welcome','.step[data-step="1"]':'<span>02</span> Language','.step[data-step="2"]':'<span>03</span> Region','.step[data-step="3"]':'<span>04</span> Keyboard','.step[data-step="4"]':'<span>05</span> Your account','.step[data-step="5"]':'<span>06</span> Storage','.step[data-step="6"]':'<span>07</span> Summary',
        '[data-page="0"] .kicker':'A NEW BEGINNING','[data-page="0"] h1':'Install<br><em>Lyra OS.</em>','[data-page="0"] .lead':'A harmonious and secure desktop experience, designed to keep up with you.',
        '[data-page="1"] .kicker':'PERSONALIZATION','[data-page="1"] h1':'Speak your<br><em>language.</em>','[data-page="1"] .lead':'Choose the initial system language. You can change it later.',
        '[data-page="2"] .kicker':'LOCATION','[data-page="2"] h1':'Your place<br><em>in the world.</em>','[data-page="2"] .lead':'The region defines date, currency and number formats, and the suggested time zone.',
        '[data-page="3"] .kicker':'INPUT','[data-page="3"] h1':'Every key<br><em>in its place.</em>','[data-page="3"] .lead':'Choose your physical keyboard layout. You can add other layouts later in Settings.',
        '[data-page="4"] .kicker':'IDENTITY','[data-page="4"] h1':'Your space.<br><em>Your name.</em>','[data-page="4"] .lead':'Create the main Lyra OS account. It will have sudo access; root will remain locked.',
        '[data-page="5"] .kicker':'DESTINATION','[data-page="5"] h1':'Where will Lyra<br><em>live?</em>','[data-page="5"] .lead':'Choose the entire disk for the system and how Lyra should use virtual memory.',
        '[data-page="6"] .kicker':'ALMOST THERE','[data-page="6"] h1':'Ready to<br><em>begin.</em>','[data-page="6"] .lead':'Review your choices. When started, the selected destination will be erased and Lyra OS will be installed.',
        '.feature-item:nth-child(1) strong':'Rust core','.feature-item:nth-child(1) small':'Safe by design','.feature-item:nth-child(2) strong':'Integrated GNOME','.feature-item:nth-child(2) small':'Light, familiar and elegant',
        '.map-hint':'Select a pin to set the time zone','.timezone-selection span':'Selected time zone','.region-preview span':'Regional preview','.keyboard-note':'<span>⌨</span> ABNT2 is recommended for physical keyboards sold in Brazil.','.storage-option-label':'VIRTUAL MEMORY',
        '.swap-card:nth-child(1) strong':'No swap','.swap-card:nth-child(1) small':'Does not create swap or enable ZRAM','.swap-card:nth-child(2) strong':'Disk swap','.swap-card:nth-child(2) small':'Dedicated 8 GiB partition','.swap-card:nth-child(3) small':'Compressed memory without using disk space',
        '.safe-note':'<span>✓</span> This step only reads the current disk state and calculates a plan — no destructive operation runs here.',
        '.summary-list div:nth-child(1) span':'Language','.summary-list div:nth-child(2) span':'Device','.summary-list div:nth-child(3) span':'Account','.summary-list div:nth-child(4) span':'Destination','.summary-list div:nth-child(5) span':'Virtual memory',
        '#back':'← Back','#next':'Continue <span>→</span>','#install':'Install Lyra OS','#reboot':'Restart system <span aria-hidden="true">↻</span>',
        '#install-status-title':'Preparing the installation…',
        '#install-confirm-text':'I understand that the destination data will be permanently erased.',
      },
      labels:{'.timezone-picker':'Time zone','.account-field:nth-child(1)':'Full name','.account-field:nth-child(2)':'Username','.account-field:nth-child(3)':'Device name','.account-field:nth-child(4)':'Password','.account-field:nth-child(5)':'Confirm password'},
      placeholders:{'#language-search':'Search languages…','#keyboard-search':'Search language, country or variant…','#full-name':'What should we call you?','#username':'Suggested from your full name','#password':'At least 8 characters','#password-confirm':'Repeat the password'},
    },
    'pt-BR':{
      title:'Instalar o Lyra OS',back:'← Voltar',next:'Continuar <span>→</span>',step:'ETAPA {current} / 07',
      languageCount:'{count} idiomas disponíveis',noLanguages:'Nenhum idioma encontrado. Tente outro termo.',
      keyboardCount:'{count} layouts disponíveis',noKeyboards:'Nenhum layout encontrado. Tente outro termo.',
      diskCount:'{count} disco{s} detectado{s}',noDisks:'Nenhum disco foi encontrado nesta sessão.',detectingDisks:'Detectando discos…',
      waitingInput:'Aguardando preenchimento',waitingSelection:'Aguardando seleção',unknownTransport:'Transporte desconhecido',
      installAuthorizing:'Autorizando e iniciando a instalação…',installStarted:'Preparando a instalação…',installing:'Instalando o Lyra OS…',
      installWarning:'O instalador emitiu um aviso',installFailed:'A instalação foi interrompida',installCompleted:'Instalação e limpeza concluídas',installRetry:'Tentar instalar novamente',
      static:{
        '.rail-footer':'<span class="status-dot"></span> Sessão live segura',
        '.step[data-step="0"]':'<span>01</span> Boas-vindas','.step[data-step="1"]':'<span>02</span> Idioma','.step[data-step="2"]':'<span>03</span> Região','.step[data-step="3"]':'<span>04</span> Teclado','.step[data-step="4"]':'<span>05</span> Sua conta','.step[data-step="5"]':'<span>06</span> Armazenamento','.step[data-step="6"]':'<span>07</span> Resumo',
        '[data-page="0"] .kicker':'UM NOVO COMEÇO','[data-page="0"] h1':'Instale o<br><em>Lyra OS.</em>','[data-page="0"] .lead':'Uma experiência desktop harmoniosa, segura e feita para acompanhar o seu ritmo.',
        '[data-page="1"] .kicker':'PERSONALIZAÇÃO','[data-page="1"] h1':'Fale a sua<br><em>linguagem.</em>','[data-page="1"] .lead':'Escolha o idioma inicial do sistema. Você poderá mudar essa opção depois.',
        '[data-page="2"] .kicker':'LOCALIZAÇÃO','[data-page="2"] h1':'Seu lugar<br><em>no mundo.</em>','[data-page="2"] .lead':'A região define formatos de data, moeda, números e o fuso horário sugerido para o sistema.',
        '[data-page="3"] .kicker':'ENTRADA','[data-page="3"] h1':'Cada tecla<br><em>no lugar.</em>','[data-page="3"] .lead':'Escolha o layout físico do seu teclado. Você poderá adicionar outros layouts depois nas Configurações.',
        '[data-page="4"] .kicker':'IDENTIDADE','[data-page="4"] h1':'Seu espaço.<br><em>Seu nome.</em>','[data-page="4"] .lead':'Crie a conta principal do Lyra OS. Ela terá acesso administrativo via sudo; root permanecerá bloqueado.',
        '[data-page="5"] .kicker':'DESTINO','[data-page="5"] h1':'Onde o Lyra<br><em>vai viver?</em>','[data-page="5"] .lead':'Escolha o disco inteiro que receberá o sistema e como o Lyra deve usar memória virtual.',
        '[data-page="6"] .kicker':'QUASE LÁ','[data-page="6"] h1':'Pronto para<br><em>começar.</em>','[data-page="6"] .lead':'Revise suas escolhas. Ao iniciar, o destino selecionado será apagado e o Lyra OS será instalado de verdade.',
        '.feature-item:nth-child(1) strong':'Rust no núcleo','.feature-item:nth-child(1) small':'Seguro por construção','.feature-item:nth-child(2) strong':'GNOME integrado','.feature-item:nth-child(2) small':'Leve, familiar e elegante',
        '.map-hint':'Selecione um pin para definir o fuso horário','.timezone-selection span':'Fuso horário selecionado','.region-preview span':'Prévia regional','.keyboard-note':'<span>⌨</span> O layout recomendado para teclados físicos vendidos no Brasil é ABNT2.','.storage-option-label':'MEMÓRIA VIRTUAL',
        '.swap-card:nth-child(1) strong':'Sem swap','.swap-card:nth-child(1) small':'Não cria swap nem ativa ZRAM','.swap-card:nth-child(2) strong':'Swap em disco','.swap-card:nth-child(2) small':'Partição dedicada de 8 GiB','.swap-card:nth-child(3) small':'Memória comprimida, sem ocupar o disco',
        '.safe-note':'<span>✓</span> Esta etapa apenas lê o estado atual dos discos e calcula um plano — nenhuma operação destrutiva é executada aqui.',
        '.summary-list div:nth-child(1) span':'Idioma','.summary-list div:nth-child(2) span':'Dispositivo','.summary-list div:nth-child(3) span':'Conta','.summary-list div:nth-child(4) span':'Destino','.summary-list div:nth-child(5) span':'Memória virtual',
        '#back':'← Voltar','#next':'Continuar <span>→</span>','#install':'Instalar o Lyra OS','#reboot':'Reiniciar o sistema <span aria-hidden="true">↻</span>',
        '#install-status-title':'Preparando a instalação…',
        '#install-confirm-text':'Entendo que os dados do destino serão apagados permanentemente.',
      },
      labels:{'.timezone-picker':'Fuso horário','.account-field:nth-child(1)':'Nome completo','.account-field:nth-child(2)':'Nome de usuário','.account-field:nth-child(3)':'Nome do dispositivo','.account-field:nth-child(4)':'Senha','.account-field:nth-child(5)':'Confirmar senha'},
      placeholders:{'#language-search':'Buscar idioma…','#keyboard-search':'Buscar idioma, país ou variante…','#full-name':'Como devemos chamar você?','#username':'Sugerido a partir do nome completo','#password':'Mínimo de 8 caracteres','#password-confirm':'Repita a senha'},
    },
    'es-ES':{
      title:'Instalar Lyra OS',back:'← Atrás',next:'Continuar <span>→</span>',step:'PASO {current} / 07',
      languageCount:'{count} idiomas disponibles',noLanguages:'No se encontraron idiomas. Prueba otra búsqueda.',
      keyboardCount:'{count} distribuciones disponibles',noKeyboards:'No se encontraron distribuciones. Prueba otra búsqueda.',
      diskCount:'{count} disco{s} detectado{s}',noDisks:'No se encontraron discos en esta sesión.',detectingDisks:'Detectando discos…',
      waitingInput:'Pendiente de completar',waitingSelection:'Pendiente de selección',unknownTransport:'Transporte desconocido',
      installAuthorizing:'Autorizando e iniciando la instalación…',installStarted:'Preparando la instalación…',installing:'Instalando Lyra OS…',
      installWarning:'El instalador emitió una advertencia',installFailed:'La instalación fue interrumpida',installCompleted:'Instalación y limpieza completadas',installRetry:'Intentar instalar de nuevo',
      static:{
        '.rail-footer':'<span class="status-dot"></span> Sesión live segura',
        '.step[data-step="0"]':'<span>01</span> Bienvenida','.step[data-step="1"]':'<span>02</span> Idioma','.step[data-step="2"]':'<span>03</span> Región','.step[data-step="3"]':'<span>04</span> Teclado','.step[data-step="4"]':'<span>05</span> Tu cuenta','.step[data-step="5"]':'<span>06</span> Almacenamiento','.step[data-step="6"]':'<span>07</span> Resumen',
        '[data-page="0"] .kicker':'UN NUEVO COMIENZO','[data-page="0"] h1':'Instala<br><em>Lyra OS.</em>','[data-page="0"] .lead':'Una experiencia de escritorio armoniosa y segura, diseñada para acompañarte.',
        '[data-page="1"] .kicker':'PERSONALIZACIÓN','[data-page="1"] h1':'Habla tu<br><em>idioma.</em>','[data-page="1"] .lead':'Elige el idioma inicial del sistema. Podrás cambiarlo más tarde.',
        '[data-page="2"] .kicker':'UBICACIÓN','[data-page="2"] h1':'Tu lugar<br><em>en el mundo.</em>','[data-page="2"] .lead':'La región define los formatos y la zona horaria sugerida para el sistema.',
        '[data-page="3"] .kicker':'ENTRADA','[data-page="3"] h1':'Cada tecla<br><em>en su lugar.</em>','[data-page="3"] .lead':'Elige la distribución física del teclado. Podrás añadir otras más tarde.',
        '[data-page="4"] .kicker':'IDENTIDAD','[data-page="4"] h1':'Tu espacio.<br><em>Tu nombre.</em>','[data-page="4"] .lead':'Crea la cuenta principal de Lyra OS. Tendrá acceso sudo; root seguirá bloqueado.',
        '[data-page="5"] .kicker':'DESTINO','[data-page="5"] h1':'¿Dónde vivirá<br><em>Lyra?</em>','[data-page="5"] .lead':'Elige el disco completo y cómo utilizar la memoria virtual.',
        '[data-page="6"] .kicker':'CASI LISTO','[data-page="6"] h1':'Todo listo para<br><em>empezar.</em>','[data-page="6"] .lead':'Revisa tus opciones. El destino seleccionado se borrará al iniciar.',
        '.map-hint':'Selecciona una zona horaria en la lista','.timezone-selection span':'Zona horaria seleccionada','.region-preview span':'Vista previa regional','.keyboard-note':'<span>⌨</span> Elige la distribución correspondiente a tu teclado físico.','.storage-option-label':'MEMORIA VIRTUAL',
        '.swap-card:nth-child(1) strong':'Sin swap','.swap-card:nth-child(1) small':'No crea swap ni activa ZRAM','.swap-card:nth-child(2) strong':'Swap en disco','.swap-card:nth-child(2) small':'Partición dedicada de 8 GiB','.swap-card:nth-child(3) small':'Memoria comprimida sin usar espacio en disco',
        '.safe-note':'<span>✓</span> Este paso solo lee los discos y calcula un plan; no ejecuta operaciones destructivas.',
        '.summary-list div:nth-child(1) span':'Idioma','.summary-list div:nth-child(2) span':'Dispositivo','.summary-list div:nth-child(3) span':'Cuenta','.summary-list div:nth-child(4) span':'Destino','.summary-list div:nth-child(5) span':'Memoria virtual',
        '#back':'← Atrás','#next':'Continuar <span>→</span>','#install':'Instalar Lyra OS','#reboot':'Reiniciar el sistema <span aria-hidden="true">↻</span>','#install-confirm-text':'Entiendo que los datos del destino se borrarán permanentemente.',
        '#install-status-title':'Preparando la instalación…',
      },
      labels:{'.timezone-picker':'Zona horaria','.account-field:nth-child(1)':'Nombre completo','.account-field:nth-child(2)':'Nombre de usuario','.account-field:nth-child(3)':'Nombre del dispositivo','.account-field:nth-child(4)':'Contraseña','.account-field:nth-child(5)':'Confirmar contraseña'},
      placeholders:{'#language-search':'Buscar idiomas…','#keyboard-search':'Buscar idioma, país o variante…','#full-name':'¿Cómo debemos llamarte?','#username':'Sugerido a partir del nombre completo','#password':'Mínimo 8 caracteres','#password-confirm':'Repite la contraseña'},
    },
    'zh-CN':{
      title:'安装 Lyra OS',back:'← 返回',next:'继续 <span>→</span>',step:'第 {current} 步 / 共 07 步',
      languageCount:'共有 {count} 种语言',noLanguages:'未找到语言，请尝试其他关键词。',
      keyboardCount:'共有 {count} 种键盘布局',noKeyboards:'未找到键盘布局，请尝试其他关键词。',
      diskCount:'检测到 {count} 个磁盘',noDisks:'此会话中未找到磁盘。',detectingDisks:'正在检测磁盘…',
      waitingInput:'等待填写',waitingSelection:'等待选择',unknownTransport:'未知传输类型',
      installAuthorizing:'正在授权并开始安装…',installStarted:'正在准备安装…',installing:'正在安装 Lyra OS…',
      installWarning:'安装程序报告了警告',installFailed:'安装已中断',installCompleted:'安装和清理已完成',installRetry:'重试安装',
      static:{
        '.rail-footer':'<span class="status-dot"></span> 安全的 Live 会话',
        '.step[data-step="0"]':'<span>01</span> 欢迎','.step[data-step="1"]':'<span>02</span> 语言','.step[data-step="2"]':'<span>03</span> 地区','.step[data-step="3"]':'<span>04</span> 键盘','.step[data-step="4"]':'<span>05</span> 账户','.step[data-step="5"]':'<span>06</span> 存储','.step[data-step="6"]':'<span>07</span> 摘要',
        '[data-page="0"] .kicker':'全新的开始','[data-page="0"] h1':'安装<br><em>Lyra OS。</em>','[data-page="0"] .lead':'和谐、安全且贴合您节奏的桌面体验。',
        '[data-page="1"] .kicker':'个性化','[data-page="1"] h1':'选择您的<br><em>语言。</em>','[data-page="1"] .lead':'选择系统的初始语言，之后仍可更改。',
        '[data-page="2"] .kicker':'位置','[data-page="2"] h1':'您在世界上的<br><em>位置。</em>','[data-page="2"] .lead':'地区决定日期、货币、数字格式和建议的时区。',
        '[data-page="3"] .kicker':'输入','[data-page="3"] h1':'让每个按键<br><em>各就各位。</em>','[data-page="3"] .lead':'选择实体键盘布局，之后可在设置中添加其他布局。',
        '[data-page="4"] .kicker':'身份','[data-page="4"] h1':'您的空间，<br><em>您的名字。</em>','[data-page="4"] .lead':'创建 Lyra OS 主账户。该账户拥有 sudo 权限，root 保持锁定。',
        '[data-page="5"] .kicker':'目标位置','[data-page="5"] h1':'Lyra 将安装在<br><em>哪里？</em>','[data-page="5"] .lead':'选择完整磁盘以及虚拟内存的使用方式。',
        '[data-page="6"] .kicker':'即将完成','[data-page="6"] h1':'准备好<br><em>开始。</em>','[data-page="6"] .lead':'请检查您的选择。开始后，所选目标中的数据将被清除。',
        '.map-hint':'从列表中选择时区','.timezone-selection span':'已选时区','.region-preview span':'地区预览','.keyboard-note':'<span>⌨</span> 请选择与实体键盘对应的布局。','.storage-option-label':'虚拟内存',
        '.swap-card:nth-child(1) strong':'不使用交换空间','.swap-card:nth-child(1) small':'不创建交换分区，也不启用 ZRAM','.swap-card:nth-child(2) strong':'磁盘交换空间','.swap-card:nth-child(2) small':'专用 8 GiB 分区','.swap-card:nth-child(3) small':'不占用磁盘空间的压缩内存',
        '.safe-note':'<span>✓</span> 此步骤仅读取磁盘状态并计算方案，不会执行破坏性操作。',
        '.summary-list div:nth-child(1) span':'语言','.summary-list div:nth-child(2) span':'设备','.summary-list div:nth-child(3) span':'账户','.summary-list div:nth-child(4) span':'目标位置','.summary-list div:nth-child(5) span':'虚拟内存',
        '#back':'← 返回','#next':'继续 <span>→</span>','#install':'安装 Lyra OS','#reboot':'重新启动系统 <span aria-hidden="true">↻</span>','#install-confirm-text':'我了解目标位置中的数据将被永久清除。',
        '#install-status-title':'正在准备安装…',
      },
      labels:{'.timezone-picker':'时区','.account-field:nth-child(1)':'姓名','.account-field:nth-child(2)':'用户名','.account-field:nth-child(3)':'设备名称','.account-field:nth-child(4)':'密码','.account-field:nth-child(5)':'确认密码'},
      placeholders:{'#language-search':'搜索语言…','#keyboard-search':'搜索语言、国家或变体…','#full-name':'我们该如何称呼您？','#username':'根据姓名建议','#password':'至少 8 个字符','#password-confirm':'再次输入密码'},
    },
  };
  let current='en-US';
  const interpolate=(value,vars={})=>String(value).replace(/\{(\w+)\}/g,(_,key)=>vars[key]??`{${key}}`);
  function t(key,vars={}){return interpolate(catalogs[current]?.[key]??catalogs['en-US'][key]??key,vars)}
  function apply(locale){
    current=catalogs[locale]?locale:'en-US';
    document.documentElement.lang=current;
    document.title=t('title');
    const merged={...catalogs['en-US'].static,...catalogs[current].static};
    Object.entries(merged).forEach(([selector,value])=>{const element=document.querySelector(selector);if(element)element.innerHTML=value});
    const placeholders={...catalogs['en-US'].placeholders,...catalogs[current].placeholders};
    Object.entries(placeholders).forEach(([selector,value])=>{const element=document.querySelector(selector);if(element)element.placeholder=value});
    const labels={...catalogs['en-US'].labels,...catalogs[current].labels};
    Object.entries(labels).forEach(([selector,value])=>{const element=document.querySelector(selector);if(element&&element.firstChild)element.firstChild.textContent=value});
  }
  function register(locale,catalog){catalogs[locale]=catalog}
  return {apply,t,register,get locale(){return current}};
})();
