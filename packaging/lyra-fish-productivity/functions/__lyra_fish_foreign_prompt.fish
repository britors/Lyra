function __lyra_fish_foreign_prompt \
    --description "True when this account already configures a prompt hydro must not replace"

    for file in $__fish_config_dir/config.fish $__fish_config_dir/conf.d/*.fish
        test -f $file; or continue
        if string match --quiet --regex --ignore-case \
                '(starship|oh-my-posh|tide|powerline|fish_prompt)' -- (cat $file | string collect)
            return 0
        end
    end

    set --local prompt $__fish_config_dir/functions/fish_prompt.fish
    if test -f $prompt
        # hydro's own prompt is not a conflict with itself.
        if not string match --quiet --regex '_hydro' -- (cat $prompt | string collect)
            return 0
        end
    end

    return 1
end
