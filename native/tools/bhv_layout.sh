#!/bin/sh
# Lists the objects of data/behavior_data.c in source order as BHV(name), STATIC_BHV(name) or FILLER_U64().
grep -E "^(UNUSED static const u64|UNUSED static const BehaviorScript|const BehaviorScript) " "$1" | while read -r line; do
    case "$line" in
        "UNUSED static const u64"*)
            echo "FILLER_U64()"
            ;;
        "UNUSED static const BehaviorScript "*)
            name=${line#UNUSED static const BehaviorScript }
            echo "STATIC_BHV(${name%%\[*})"
            ;;
        "const BehaviorScript "*)
            name=${line#const BehaviorScript }
            echo "BHV(${name%%\[*})"
            ;;
    esac
done
