# Set per-user state paths before any vendor/user plugin is sourced.
if not set -q LYRA_FISH_SEED
    set -l lyra_passwd_home (getent passwd (id -u) | string split --fields 6 ':')
    if test (count $lyra_passwd_home) -eq 1; and test -n "$lyra_passwd_home[1]"
        set -gx HOME $lyra_passwd_home[1]
    end
    if test (id -u) -ne 0
        set -gx XDG_DATA_HOME "$HOME/.local/share"

        # jethrokuan/z persists both names as universal variables. A seed
        # produced while the image is built as root must never make a desktop
        # account touch /root. Global values deliberately shadow any stale
        # universal values before the plugin's z.fish snippet is sourced.
        set -gx Z_DATA_DIR "$XDG_DATA_HOME/z"
        set -gx Z_DATA "$Z_DATA_DIR/data"
    end
end
