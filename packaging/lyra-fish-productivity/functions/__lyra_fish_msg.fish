function __lyra_fish_msg --description "Localized messages of the Lyra Fish Productivity Pack"
    set --local key $argv[1]
    set --local locale (__lyra_fish_locale)
    set --local format

    switch $key
        case setup-start
            switch $locale
                case pt
                    set format 'Lyra: preparando o Fish Productivity Pack (só uma vez)…'
                case es
                    set format 'Lyra: preparando el Fish Productivity Pack (solo una vez)…'
                case '*'
                    set format 'Lyra: setting up the Fish Productivity Pack (only once)…'
            end
        case missing-tool
            switch $locale
                case pt
                    set format 'Lyra: %s é necessário e não está instalado.'
                case es
                    set format 'Lyra: %s es necesario y no está instalado.'
                case '*'
                    set format 'Lyra: %s is required and is not installed.'
            end
        case no-list
            switch $locale
                case pt
                    set format 'Lyra: lista de plugins não encontrada em %s.'
                case es
                    set format 'Lyra: lista de complementos no encontrada en %s.'
                case '*'
                    set format 'Lyra: plugin list not found at %s.'
            end
        case offline
            switch $locale
                case pt
                    set format 'Lyra: sem conexão com o GitHub; a instalação dos plugins ficou pendente.'
                case es
                    set format 'Lyra: sin conexión con GitHub; la instalación de complementos quedó pendiente.'
                case '*'
                    set format 'Lyra: no connection to GitHub; plugin setup was postponed.'
            end
        case retry-hint
            switch $locale
                case pt
                    set format 'Lyra: execute «fish_setup_lyra_plugins» para tentar de novo.'
                case es
                    set format 'Lyra: ejecute «fish_setup_lyra_plugins» para intentarlo de nuevo.'
                case '*'
                    set format 'Lyra: run «fish_setup_lyra_plugins» to try again.'
            end
        case fisher-install
            switch $locale
                case pt
                    set format 'Lyra: instalando o Fisher…'
                case es
                    set format 'Lyra: instalando Fisher…'
                case '*'
                    set format 'Lyra: installing Fisher…'
            end
        case fisher-failed
            switch $locale
                case pt
                    set format 'Lyra: não foi possível baixar o Fisher.'
                case es
                    set format 'Lyra: no fue posible descargar Fisher.'
                case '*'
                    set format 'Lyra: Fisher could not be downloaded.'
            end
        case plugins-install
            switch $locale
                case pt
                    set format 'Lyra: instalando %s plugins…'
                case es
                    set format 'Lyra: instalando %s complementos…'
                case '*'
                    set format 'Lyra: installing %s plugins…'
            end
        case plugins-failed
            switch $locale
                case pt
                    set format 'Lyra: a instalação dos plugins falhou.'
                case es
                    set format 'Lyra: la instalación de complementos falló.'
                case '*'
                    set format 'Lyra: plugin installation failed.'
            end
        case nvm-shadow
            switch $locale
                case pt
                    set format 'Lyra: nvm.fish do Fisher tem precedência sobre o pacote nvm-fish, que segue como reserva.'
                case es
                    set format 'Lyra: nvm.fish de Fisher tiene precedencia sobre el paquete nvm-fish, que queda como reserva.'
                case '*'
                    set format 'Lyra: the Fisher nvm.fish takes precedence over the nvm-fish package, which stays as the fallback.'
            end
        case prompt-kept
            switch $locale
                case pt
                    set format 'Lyra: prompt próprio detectado; o hydro ficou instalado, porém inativo.'
                case es
                    set format 'Lyra: prompt propio detectado; hydro quedó instalado, pero inactivo.'
                case '*'
                    set format 'Lyra: existing prompt detected; hydro was installed but left inactive.'
            end
        case setup-done
            switch $locale
                case pt
                    set format 'Lyra: Fish Productivity Pack pronto. Use «lyra_fish_status» para conferir.'
                case es
                    set format 'Lyra: Fish Productivity Pack listo. Use «lyra_fish_status» para verificar.'
                case '*'
                    set format 'Lyra: Fish Productivity Pack ready. Run «lyra_fish_status» to check it.'
            end
        case status-title
            switch $locale
                case pt
                    set format 'Lyra Fish Productivity Pack — estado desta conta'
                case es
                    set format 'Lyra Fish Productivity Pack — estado de esta cuenta'
                case '*'
                    set format 'Lyra Fish Productivity Pack — state of this account'
            end
        case state-active
            switch $locale
                case pt
                    set format 'instalado e ativo'
                case es
                    set format 'instalado y activo'
                case '*'
                    set format 'installed and active'
            end
        case state-inactive
            switch $locale
                case pt
                    set format 'instalado, inativo'
                case es
                    set format 'instalado, inactivo'
                case '*'
                    set format 'installed, inactive'
            end
        case state-shadowing
            switch $locale
                case pt
                    set format 'ativo, à frente da cópia do sistema'
                case es
                    set format 'activo, por delante de la copia del sistema'
                case '*'
                    set format 'active, ahead of the system copy'
            end
        case state-missing
            switch $locale
                case pt
                    set format 'ausente'
                case es
                    set format 'ausente'
                case '*'
                    set format 'missing'
            end
        case status-pending
            switch $locale
                case pt
                    set format 'A preparação ainda não rodou nesta conta.'
                case es
                    set format 'La preparación aún no se ejecutó en esta cuenta.'
                case '*'
                    set format 'Setup has not run for this account yet.'
            end
        case status-marker
            switch $locale
                case pt
                    set format 'Preparado em %s (versão %s, origem: %s).'
                case es
                    set format 'Preparado el %s (versión %s, origen: %s).'
                case '*'
                    set format 'Set up on %s (version %s, origin: %s).'
            end
        case status-outdated
            switch $locale
                case pt
                    set format 'A lista mudou na versão %s; o próximo terminal reexecuta a preparação.'
                case es
                    set format 'La lista cambió en la versión %s; la próxima terminal repite la preparación.'
                case '*'
                    set format 'The list changed in version %s; the next terminal will run setup again.'
            end
        case origin-image-seed
            switch $locale
                case pt
                    set format 'imagem'
                case es
                    set format 'imagen'
                case '*'
                    set format 'image'
            end
        case origin-runtime
            switch $locale
                case pt
                    set format 'esta máquina'
                case es
                    set format 'esta máquina'
                case '*'
                    set format 'this machine'
            end
        case usage
            switch $locale
                case pt
                    set format 'Uso: fish_setup_lyra_plugins [--help]\n\nInstala a lista canônica inteira de plugins nesta conta.\nUse «lyra_fish_status» para conferir o resultado.'
                case es
                    set format 'Uso: fish_setup_lyra_plugins [--help]\n\nInstala la lista canónica completa de complementos en esta cuenta.\nUse «lyra_fish_status» para verificar el resultado.'
                case '*'
                    set format 'Usage: fish_setup_lyra_plugins [--help]\n\nInstalls the whole canonical plugin list for this account.\nRun «lyra_fish_status» to check the result.'
            end
        case status-usage
            switch $locale
                case pt
                    set format 'Uso: lyra_fish_status [--help]\n\nMostra, plugin a plugin, o que esta conta tem instalado e ativo.'
                case es
                    set format 'Uso: lyra_fish_status [--help]\n\nMuestra, complemento a complemento, qué tiene instalado y activo esta cuenta.'
                case '*'
                    set format 'Usage: lyra_fish_status [--help]\n\nShows, plugin by plugin, what this account has installed and active.'
            end
        case '*'
            set format $key
    end

    printf "$format\n" $argv[2..]
end
