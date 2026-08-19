function __lyra_fish_state_dir --description "Per-user state directory of the Lyra Fish Productivity Pack"
    if set --query XDG_STATE_HOME; and test -n "$XDG_STATE_HOME"
        echo $XDG_STATE_HOME/lyra-fish-productivity
    else
        echo $HOME/.local/state/lyra-fish-productivity
    end
end
