# Lyra OS interactive shell defaults. User configuration loaded from
# ~/.config/fish can override these values without modifying system files.

set --global fish_greeting

# hydro is the Lyra OS prompt, installed per account by
# lyra-fish-productivity. Its colors are set here so the default prompt reads
# as Lyra and not as hydro's upstream default, which leaves everything but the
# error segment uncolored. The values mirror the vendor fish_prompt below:
# cyan path, blue git, green prompt marker, yellow timing.
#
# Ordering is what makes this work. fish sources ~/.config/fish/conf.d before
# the vendor directories (config.fish: "User > Admin > Extra"), so hydro.fish
# has already run by the time this file is read - it installed --on-variable
# handlers for each hydro_color_*, and assigning them here re-renders the
# cached escape sequences. Symbols are left alone: hydro already defaults to
# ❱ for the prompt and • for a dirty tree.
#
# hydro_color_error is deliberately not set: hydro defaults it to
# $fish_color_error, which follows the user's own theme.
set --global hydro_color_pwd cyan
set --global hydro_color_git blue
set --global hydro_color_prompt green
set --global hydro_color_duration yellow
