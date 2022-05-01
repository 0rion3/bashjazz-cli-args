#!/usr/bin/env bash
source $BASHJAZZ_PATH/utils/array.sh
source $BASHJAZZ_PATH/utils/quoted_string.sh

CliArgs() {

  # The First ARGUMENT to this function is the name of the nested function to
  # be called. The actual calls will be done after all function declarations.
  # Here, we need to to shift $@ after we assign the name of the nested function
  # to the CALL_NESTED variable.
  local CALL_NESTED="$1"
  shift

  # Constants (because of the flag -r) used by CLI arguments
  local -r ARG_VALUE_TRUE="${ARG_VALUE_TRUE:-yes}"
  local -r ARG_VALUE_FALSE="${ARG_VALUE_FALSE:-no}"

  # User may want to parse arguments for various scripts or even separate
  # functions inside each script which may all be a part of a larger program.
  # Therefore, we need to store arguments data for each call separately.
  # This will be done via associative arrays where each key is the NAME of the
  # caller and each value is a pseudo-array string. Users of CliArgs() won't
  # have to worry about these details, this is all internal.
  #
  # NAME can be provided by the user himself via the CALLER variable in front
  # of the actual invocation of `CliArgs()` or it'll be assigned automatically,
  # by fetching caller-script filename. If, for some, reason automatic assignment
  # fails, NAME will given the value "default".
  #
  local NAME="$CALLER" # can only contain alphanumeric characters and "_"
  if [[ -z "$NAME" ]]; then
    caller | grep -ovE '^[0-9]+' | grep -ovE '.[a-zA-Z]$' | sed 's/-/_/g' |
      read _ NAME # reads caller script name into the $NAME variable
    NAME="${NAME:-default}"
  fi

  extract_synonyms() {
    echo $(echo "${@}" | \
      sed -E 's/:[^ ]+/ /g')
  }

  get_arg_name() {
    local arg_name=$(echo $1 | sed 's/-/_/g')
    local arg_names=( ${!ARG_DEF_all_args_FOR_$NAME} )
    local synonyms=(  ${!ARG_DEF_synonyms_FOR_$NAME} )

    local real_arg_name="$(echo "${arg_names[@]}" | grep -o "$arg_name")"

    if [[ -z "$real_arg_name" ]]; then
      local item_index=$(${arg_synonyms[@]/$arg_name//} | \
        cut -d/ -f1 | wc -w | tr -d ' ')
    fi

    local real_arg_name="${arg_names[$item_index]}"
    echo "$real_arg_name"
  }

  get_value_for() {
    # TODO
    return 0
  }

  add_arg_data_for_name() {
    local var_prefix="$1"
    # xargs removes leading/trailing whitespace here
    local global_var_value="$(echo $2 | xargs)"
    local global_var_name="ARG_DEF_${var_prefix}_FOR_$NAME"

    declare -g "$global_var_name"="$global_var_value"
    echo "$global_var_name=\"${global_var_value:-$ARG_VALUE_TRUE}\""
  }

  define() {

    local allowed=(
      no_value_args default_value_args value_args required_args ignore_errors
    )
    local args=( ${@} )
    local out
    local all_args

    for k in "${!args[@]}"; do

      local arg="${args[$k]}"

      local arg_name="$(echo "$arg" | \
        grep -o '^\-\-[a-z\-]*' | sed 's/^--//' | sed 's/-/_/g')"

      local value="$(echo "$arg" | sed -E "s/--[a-z\-]+=?//g" | sed 's/,/ /g')"

      Array_contains $arg_name "${allowed[@]}" > /dev/null || continue

      if [[ "$arg_name" =~ ^(no_)?value_args$ ]]; then
        all_args+="$value "
      fi

      # The next line of code removes the ":" character, which means we only
      # keeps the two-dash argument names in these variables or,
      # if a cli-arg only has a one-dash version, then that's the one that will
      # be kept. This is fine, because get_value_for() will take either a
      # synonym or an actual name and return a value we'll extract later on.
      value="$(echo "$value" | sed -E 's/(^| )[a-zA-Z]:/ /g')"
      echo "$(add_arg_data_for_name $arg_name "$value")"
    done

    local synonyms="$(extract_synonyms "$all_args")"
    echo "$(add_arg_data_for_name 'all_args' "$all_args")"
    echo "$(add_arg_data_for_name 'synonyms' "$synonyms")"
  }

  parse() {

    local name="${1:-$NAME}"

    while $# -gt 0; do
      arg="$1"
      shift

      # $arg is either a one-dash or a two-dash argument such as
      # -i or --input-fn
      if [[ "$arg" == "-"* ]]; then
        echo 0 > /dev/null
      # Case for when it's something like my-script -i file.txt
      # and $arg == "file.txt"
      elif [[ -n "$value_for_prev_arg" ]]; then
        echo 0 > /dev/null
      # This is a positional argument
      else
        echo 0 > /dev/null
      fi

      # Process $arg in several steps:
      # 1. If argument starts with a dash or two dashes - it's non-positional:
      #
      #      1) Determine if it's allowed
      #      2) Determine if it requires value and assign it.
      #      3) Determine if value is optional, assign default or provided.
      #      4) Determine if value is not allowed
      #         (which means an argument may be followed by a positional argument).
      #
      # 2. If arguments starts with an alphanumeric character:
      #
      #    1) Check if previous argument was a one-dash argument that was
      #       expecting a value. If yes, then this argument IS NOT a positional
      #       argument, but a value to the non-positional one-dash argument.
      # 
      #    2) Otherwise treat this argument as a positional argument.

    done

  }

  # ATTENTION: here the program will exit if a non-existent nested function
  # was called.
  $CALL_NESTED $@
  exit $?

}
