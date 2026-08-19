function lyra_fish_status --description "Report the state of the Lyra fish productivity plugins for this account"
    argparse --name=lyra_fish_status h/help -- $argv
    or return 2

    if set --query _flag_help
        __lyra_fish_msg status-usage
        return 0
    end

    # Overridable so the image build and the test suite can point at a tree
    # that is not installed under /usr yet.
    set --local share /usr/share/lyra-fish-productivity
    set --query LYRA_FISH_SHARE_DIR; and test -n "$LYRA_FISH_SHARE_DIR"
    and set share $LYRA_FISH_SHARE_DIR
    set --local list_file $share/fish_plugins
    set --local state (__lyra_fish_state_dir)

    if not test -r $list_file
        __lyra_fish_msg no-list $list_file >&2
        return 1
    end

    __lyra_fish_msg status-title
    echo

    set --local marker_version
    set --local marker_date
    set --local marker_origin
    if test -r $state/installed
        for line in (cat $state/installed)
            set --local pair (string split --max 1 '=' -- $line)
            test (count $pair) -eq 2; or continue
            switch $pair[1]
                case version
                    set marker_version $pair[2]
                case date
                    set marker_date $pair[2]
                case origin
                    set marker_origin $pair[2]
            end
        end
    end

    if test -n "$marker_version"
        test -n "$marker_origin"; or set marker_origin runtime
        set --local origin_label (__lyra_fish_msg origin-$marker_origin)
        __lyra_fish_msg status-marker $marker_date $marker_version $origin_label
        set --local packaged (__lyra_fish_version)
        test "$marker_version" != "$packaged"
        and __lyra_fish_msg status-outdated $packaged
    else
        __lyra_fish_msg status-pending
    end
    echo

    # Fisher's manifest is the source of truth for what this account has;
    # it records refs lowercased, so compare that way.
    set --local manifest
    if test -r $__fish_config_dir/fish_plugins
        set manifest (string lower -- (cat $__fish_config_dir/fish_plugins))
    end

    set --local missing 0
    for line in (cat $list_file)
        set line (string trim -- $line)
        test -n "$line"; or continue
        string match --quiet --regex '^#' -- $line; and continue

        set --local plugin (string split '/' -- $line)[-1]
        set --local installed 0

        if test "$plugin" = fisher
            functions --query fisher; and set installed 1
        else if contains -- (string lower -- $line) $manifest
            set installed 1
        end

        set --local state_text
        if test $installed -eq 0
            set state_text (__lyra_fish_msg state-missing)
            set missing 1
        else
            switch $plugin
                case hydro
                    # hydro owns fish_prompt; a foreign prompt leaves it dormant.
                    set --local prompt $__fish_config_dir/functions/fish_prompt.fish
                    if test -f $prompt; and string match --quiet --regex '_hydro' -- (cat $prompt | string collect)
                        set state_text (__lyra_fish_msg state-active)
                    else
                        set state_text (__lyra_fish_msg state-inactive)
                    end
                case nvm.fish
                    if __lyra_fish_system_provides nvm
                        set state_text (__lyra_fish_msg state-shadowing)
                    else
                        set state_text (__lyra_fish_msg state-active)
                    end
                case '*'
                    set state_text (__lyra_fish_msg state-active)
            end
        end

        printf '  %-28s %s\n' $line $state_text
    end

    if test $missing -eq 1
        echo
        __lyra_fish_msg retry-hint
        return 1
    end

    return 0
end
