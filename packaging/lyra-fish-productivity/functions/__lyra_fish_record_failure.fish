function __lyra_fish_record_failure --description "Timestamp a failed setup so the automatic retry backs off"
    set --local state (__lyra_fish_state_dir)
    mkdir --parents $state; or return 1
    date +%s >$state/last-failure
end
