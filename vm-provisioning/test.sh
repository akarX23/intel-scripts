#!/bin/bash

existing_targets=$(virsh domblklist --domain k8-test-1 | awk '/v[a-z]*/{print $1}' | awk '{print $NF}')
readarray -t target_arr <<< "$existing_targets"
next_target=""

i=0
for i in "${!target_arr[@]}"; do
    target="${target_arr[$i]}"

    if [ $i -lt $((${#target_arr[@]}-1)) ]; then
        next_target_in_loop="${target_arr[$i+1]}"
    else
        next_target_in_loop=""
    fi

    next_suffix=$(echo "$target" | sed 's/.*\(.\)$/\1/' | tr 'a-y' 'b-z')
    next_target=$(echo "$target" | awk '{print substr($0, 1, length-1)}')$next_suffix

    if [ "$next_target" != "$next_target_in_loop" ]; then
        break
    fi
done

echo "Next available target for $domain: $next_target"