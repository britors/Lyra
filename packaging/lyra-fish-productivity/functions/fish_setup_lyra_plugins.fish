function fish_setup_lyra_plugins --description "Install the Lyra fish productivity plugins for this account"
    argparse --name=fish_setup_lyra_plugins h/help -- $argv
    or return 2

    if set --query _flag_help
        __lyra_fish_msg usage
        return 0
    end

    # Overridable so the image build and the test suite can point at a tree
    # that is not installed under /usr yet.
    set --local share /usr/share/lyra-fish-productivity
    set --query LYRA_FISH_SHARE_DIR; and test -n "$LYRA_FISH_SHARE_DIR"
    and set share $LYRA_FISH_SHARE_DIR
    set --local list_file $share/fish_plugins
    set --local fisher_ref main
    set --query LYRA_FISH_FISHER_REF; and test -n "$LYRA_FISH_FISHER_REF"
    and set fisher_ref $LYRA_FISH_FISHER_REF
    set --local fisher_url https://raw.githubusercontent.com/jorgebucaran/fisher/$fisher_ref/functions/fisher.fish
    set --local state (__lyra_fish_state_dir)

    if not test -r $list_file
        __lyra_fish_msg no-list $list_file >&2
        return 1
    end

    for tool in curl git
        if not command --query $tool
            __lyra_fish_msg missing-tool $tool >&2
            return 1
        end
    end

    __lyra_fish_msg setup-start

    # Two hosts, two probes: fisher.fish comes from raw.githubusercontent.com,
    # but `fisher install` fetches the tarballs from api.github.com. Probing
    # only the first one greenlights a network that can reach it and then
    # fails halfway through the install. An offline machine costs at most
    # --max-time seconds per host, never a hung shell.
    for probe in $fisher_url https://api.github.com/
        if not curl --silent --location --fail --head --connect-timeout 5 --max-time 10 \
                --output /dev/null $probe
            __lyra_fish_record_failure
            __lyra_fish_msg offline >&2
            __lyra_fish_msg retry-hint >&2
            return 1
        end
    end

    if not functions --query fisher
        __lyra_fish_msg fisher-install
        set --local download (mktemp)
        if not curl --silent --location --fail --connect-timeout 5 --max-time 60 \
                --output $download $fisher_url
            rm --force $download
            __lyra_fish_record_failure
            __lyra_fish_msg fisher-failed >&2
            __lyra_fish_msg retry-hint >&2
            return 1
        end
        source $download
        set --local sourced $status
        rm --force $download
        if test $sourced -ne 0; or not functions --query fisher
            __lyra_fish_record_failure
            __lyra_fish_msg fisher-failed >&2
            __lyra_fish_msg retry-hint >&2
            return 1
        end
    end

    set --local plugins
    for line in (cat $list_file)
        set line (string trim -- $line)
        test -n "$line"; or continue
        string match --quiet --regex '^#' -- $line; and continue
        set --append plugins $line
    end

    if test (count $plugins) -eq 0
        __lyra_fish_msg no-list $list_file >&2
        return 1
    end

    # hydro owns functions/fish_prompt.fish. Preserve a prompt the user (or
    # another framework) already configured: hydro stays installed, inactive.
    set --local prompt_file $__fish_config_dir/functions/fish_prompt.fish
    set --local prompt_backup
    set --local prompt_conflict 0
    if __lyra_fish_foreign_prompt
        set prompt_conflict 1
        if test -f $prompt_file
            set prompt_backup (mktemp)
            cp --preserve=mode,timestamps $prompt_file $prompt_backup
        end
    end

    __lyra_fish_msg plugins-install (count $plugins)

    # One fisher invocation for the whole set: dependencies resolve once.
    set --local installed 0
    fisher install $plugins; and set installed 1

    if test -n "$prompt_backup"
        cp --preserve=mode,timestamps $prompt_backup $prompt_file
        rm --force $prompt_backup
    end

    if test $installed -eq 0
        __lyra_fish_record_failure
        __lyra_fish_msg plugins-failed >&2
        __lyra_fish_msg retry-hint >&2
        return 1
    end

    # nvm.fish also ships as the RPM-managed nvm-fish package, in the vendor
    # directories. The Fisher copy lands in ~/.config/fish, which precedes
    # them in $fish_function_path, so it wins by precedence: the packaged
    # one stays untouched as the fallback for accounts without this pack.
    __lyra_fish_system_provides nvm; and __lyra_fish_msg nvm-shadow
    test $prompt_conflict -eq 1; and __lyra_fish_msg prompt-kept

    # Recorded so conf.d/lyra-fish-bootstrap.fish knows this account is done,
    # and so an RPM that changes the canonical list triggers one re-run.
    set --local origin runtime
    set --query LYRA_FISH_SEED; and test -n "$LYRA_FISH_SEED"
    and set origin image-seed

    mkdir --parents $state
    or return 1
    rm --force $state/last-failure
    printf 'version=%s\ndate=%s\norigin=%s\nplugins=%s\n' \
        (__lyra_fish_version) (date --iso-8601=seconds) $origin \
        (string join ',' $plugins) >$state/installed

    __lyra_fish_msg setup-done
    return 0
end
