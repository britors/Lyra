# Lyra Fish Productivity Pack - repair and update path.
#
# A fresh install does NOT come through here: kiwi/config.sh seeds
# /etc/skel at image build time, so the first terminal of a new account
# already has everything and this snippet exits on the version check.
# What is left for runtime is an account created before the pack shipped,
# a ~/.config/fish that was wiped or restored from a backup, and an RPM
# update that changes the canonical plugin list.

status is-interactive
or return

function __lyra_fish_bootstrap --description "One-shot repair of the Lyra fish plugin set"
    set --local state (__lyra_fish_state_dir)
    set --local packaged (__lyra_fish_version)

    if test -r $state/installed
        for line in (cat $state/installed)
            set --local pair (string split --max 1 '=' -- $line)
            test (count $pair) -eq 2; or continue
            test "$pair[1]" = version; or continue
            # Same version already recorded: nothing to do, no network.
            test "$pair[2]" = "$packaged"; and return 0
        end
    end

    # An offline machine must not probe GitHub on every terminal it opens.
    if test -r $state/last-failure
        set --local last (cat $state/last-failure)
        if string match --quiet --regex '^\d+$' -- "$last"
            test (math (date +%s) - $last) -lt 86400; and return 0
        end
    end

    fish_setup_lyra_plugins
end

__lyra_fish_bootstrap
functions --erase __lyra_fish_bootstrap
