function __lyra_fish_locale --description "Resolve the message locale for the Lyra Fish Productivity Pack"
    for candidate in $LC_ALL $LC_MESSAGES $LANG
        test -n "$candidate"; or continue
        switch $candidate
            case 'pt*'
                echo pt
            case 'es*'
                echo es
            case '*'
                echo en
        end
        return 0
    end
    echo en
end
