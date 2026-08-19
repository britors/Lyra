# Lyra OS fallback prompt. The default prompt of an installed desktop is
# hydro, which lyra-fish-productivity puts in
# ~/.config/fish/functions/fish_prompt.fish - and that takes precedence over
# this file, as does any prompt the user writes there. What is left for this
# one to serve: root, the server edition, and any account that removed the
# plugin set. Keep it dependency-free for that reason.
function fish_prompt
    set --local last_status $status

    set --local arrow_color green
    test $last_status -eq 0; or set arrow_color red

    set --local arrow '➜'
    fish_is_root_user; and set arrow '#'

    set_color --bold $arrow_color
    echo -n "$arrow "
    set_color --bold cyan
    echo -n (path basename (prompt_pwd))

    if command git rev-parse --is-inside-work-tree >/dev/null 2>&1
        set --local branch (command git symbolic-ref --quiet --short HEAD 2>/dev/null)
        test -n "$branch"; or set branch (command git rev-parse --short HEAD 2>/dev/null)

        set_color --bold blue
        echo -n ' git:('
        set_color --bold red
        echo -n $branch
        set_color --bold blue
        echo -n ')'

        set --local dirty (command git status --porcelain --untracked-files=no 2>/dev/null)
        if set --query dirty[1]
            set_color --bold yellow
            echo -n ' ✗'
        end
    end

    set_color normal
    echo -n ' '
end
