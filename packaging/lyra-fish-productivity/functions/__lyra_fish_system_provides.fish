function __lyra_fish_system_provides --argument-names name \
    --description "True when an RPM already ships the named fish function"

    for directory in /usr/share/fish/vendor_functions.d /usr/local/share/fish/vendor_functions.d
        if test -f $directory/$name.fish
            return 0
        end
    end
    return 1
end
