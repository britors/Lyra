function __lyra_fish_version --description "Version of the installed Lyra Fish Productivity Pack"
    # Not named $version: that is fish's own special variable, and assigning
    # to it errors out and leaks the fish version to the caller.
    # @VERSION@ is substituted at RPM build time; an unsubstituted file still
    # returns something stable, so a run straight from a git checkout degrades
    # to "0-devel" instead of failing.
    set --local pack_version @VERSION@
    string match --quiet --regex '^@' -- $pack_version; and set pack_version 0-devel
    echo $pack_version
end
