#!/usr/bin/sh
source $(dirname ${BASH_SOURCE[0]})/core.sh
core.import logging
core.import ui
core.import utils

doc_test_eval() {
    __doc__='
    NOTE: All constructs/chars are allowed except single Quotes
    Tests are delimited by blank lines:
    >>> echo foo
    foo

    >>> echo bar
    bar

    But can also occur right after another:
    >>> echo foo
    foo
    >>> echo bar
    bar

    Some text in between.

    Return values can not be used directly:
    >>> bad() { return 1; }
    >>> bad || echo good
    good
    '
    local buffer="$1"
    local output_buffer="$2"
    local got=$'\n'"$(eval "$buffer")"
    if ! [[ "$output_buffer" == "$got" ]]; then
        echo -e "[${ui_color_lightred}FAIL${ui_color_default}]"
        #echo -e "\tlastline: $lastline"
        echo -e "${ui_color_lightred}expected:${ui_color_default}"\
            "$output_buffer"
        echo -e "${ui_color_lightred}got:${ui_color_default}"\
            "$got"
        return 1
    fi
}

doc_test_run_test() {
    #TODO add indentation support
    local teststring="$1"  # the docstring to test
    local prompt=">>>"
    local buffer=""  # content of buffer gets evaled
    local output_buffer=""
    local inside_test=false
    local inside_result=false
    reset_buffers() {
        inside_result=false
        inside_test=false
        buffer=""  # clear buffer
        output_buffer=""  # clear buffer
    }
    local line
    while read line; do
        line="$(echo -e "${line}" | sed -e 's/^[[:space:]]*//')" # lstrip
        if [[ "$line" = "" ]];then
            if $inside_test ;then
                doc_test_eval "$buffer" "$output_buffer" || return
            fi
            reset_buffers
        elif [[ "$line" = ">>>"* ]]; then # put into buffer
            if $inside_result; then
                doc_test_eval "$buffer" "$output_buffer" || return
                reset_buffers
            fi
            inside_test=true
            buffer="${buffer}"$'\n'"${line#>>>}"
        else
            $inside_test && inside_result=true
            output_buffer="${output_buffer}"$'\n'"${line}"
            ! $inside_test && ! $inside_result && reset_buffers
        fi
    done <<< "$teststring"
    echo -e "[${ui_color_lightgreen}PASS${ui_color_default}]"
}
doc_test_test_module() {
    local module=$1
    local test_identifier='__doc__'
    logging.debug "testing module '$module'"
    core.import "$module"
    local fun
    for fun in $(declare -F | cut -d' ' -f3 | grep -e "^$module" ); do
        # don't test this function (prevent funny things from happening)
        if [ $fun == $FUNCNAME ]; then
            continue
        fi
        local regex="/__doc__='/,/'/p"
        local teststring=$(
            unset $test_identifier
            eval "$(type $fun | sed -n $regex)"
            echo "${!test_identifier}"
        )
        [ -z "$teststring" ] && continue
        local result=$(doc_test_run_test "$teststring")
        logging.info "$fun":"$result"
    done
}
doc_test_parse_args() {
    if [ $# -eq 0 ]; then
        local filename
        for filename in $(dirname $0)/*; do
            local module=$(basename ${filename%.sh})
            doc_test_test_module $module
        done
    else
        local module
        for module in $@; do
            doc_test_test_module $module
        done
    fi
}
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    logging.set_log_level info
    logging.set_commands_log_level info
    doc_test_parse_args "$@"
fi
