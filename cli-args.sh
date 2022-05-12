#!/usr/bin/env bash
source $BASHJAZZ_PATH/utils/array.sh
source $BASHJAZZ_PATH/utils/formatting.sh
source $BASHJAZZ_PATH/utils/quoted_string.sh

declare -g CLIARGS_RSEP='' # U+001E, record separator
declare -g CLIARGS_USEP='' # U+001F, unit separator

NULL_SYM='␀'

CliArgs() {

  extract_synonyms() {
    echo $(echo "${@}" | \
      sed -E 's/:[^ ]+/ /g')
  }

  get_name() {
    # This is "just in case" someone passes us an argument name which has:
    #
    # 1) One or two leading dash "-" charachters in the front - then we simply
    #    strip them.
    #
    # 2) An underscore "_" separating words instead of the "dash". We replace
    # it with a dash "-" because all argument names in CliArgs() are stored
    # with underscores replacing dashes in their names, such that, for example,
    # the name "input-fn" becomes "input_fn".
    local arg_name=$(echo "$1" | sed 's/^--//' | sed 's/-/_/g')

    local arg_names_var="ARG_DEF_all_args_FOR_$CLIARGS_NS"
    local arg_synonyms_var="ARG_DEF_synonyms_FOR_$CLIARGS_NS"
    local names=(
      $(echo "${!arg_names_var}" | sed -E 's/[a-zA-Z0-9_]+[:]//g')
    )
    local synonyms=(  $(echo "${!arg_synonyms_var}") )

    local result="$(echo "${names[@]}"   | \
      grep -oE "(^|\s|:)$arg_name(\s|$)" | \
      sed 's/^://')"

    if [[ -z "$result" ]]; then
      local item_index="$(Array_get_index_for $arg_name ${synonyms[@]})"
      result="${names[$item_index]}"
    fi

    echo "$result" | xargs # again, xargs here is to remove trailing whitespace

  }

  get_value() {
    # TODO
    return 0
  }

  declare_namespace_var() {
    if [[ "$1" == "-"* ]]; then
      local var_flag="$1 "
      shift
    fi
    local var_name="$1_FOR_$CLIARGS_NS"
    shift
    declare -g "$var_name"="${var_flag}$(echo "$@" | xargs)"
  }

  append_to_namespace_var() {
    var_name="$1_FOR_$CLIARGS_NS"
    shift

    local var_addition="$(echo "$@" | xargs)"
    local var_type="$(echo "${!var_addition}" | grep -oE '^-[a-zA-Z]')"

    local var_value
    if [[ $var_type == '-A' ]]; then
      var_value="${!var_name}$var_addition${CLIARGS_RSEP}"
    elif [[ $var_type == '-a' ]]; then
      var_value="${!var_name} $var_addition"
    else
      # The difference from the above is that when we append to a string
      # we don't separate with a space.
      var_value="${!var_name}$var_addition"
    fi
    printf -v "$var_name" '%s' "$var_value"
  }

  # $1 = arr_name (without the namespace, example: ARG_DEF_all_args)
  # $2 = arr_index (integer)
  get_namespace_arr_item() {
    var_name="${2}_FOR_${CLIARGS_NS}"

    if [[ "${!var_name}" == "-A"* ]]; then
      local i="$1"
      echo "${!var_name}" | \
        grep -oE "${i}${CLIARGS_USEP}[^$CLIARGS_RSEP]+" | \
        sed "s/${i}${CLIARGS_USEP}//"
    else
      local i=$(($1+1)) # Because 0 is -a
      local arr=( $(echo "${!var_name}" ) )
      echo "${arr[$i]}"
    fi

  }

  extract_arg_name() {
    echo "$1" | grep -o '^\-\-[a-zA-Z0-0\-]+=' | \
      sed 's/^--//' | sed 's/-/_/g' | sed 's/=$//'
  }

  extract_arg_value() {
    echo "$1" | \
      sed -E "s/--[a-z\-]+=?//g" | \
      sed 's/,/ /g'              | \
      sed 's/-/_/g'
  }

  define() {

    local allowed=(
      no_value_args default_value_args value_args required_args required_values \
      ignore_errors
    )
    local args=( ${@} )
    local out
    local all_args
    local no_value_args
    local value_args
    local required_args

    for arg in "${args[@]}"; do

      local arg_name="$(extract_arg_name "$arg")"
      Array_contains $arg_name "${allowed[@]}" > /dev/null || continue

      local value="$(extract_arg_value "$arg")"

      if [[ "$arg_name" =~ ^((no_)?value|required)_(args|values)$ ]]; then
        if [[ "$arg_name" != "required_args" ]]; then
          all_args+="$value "
        fi
        value="$(echo "$value" | sed -E 's/(^| )[a-zA-Z0-9]+:/ /g')"
        printf -v "$arg_name" '%s' "${!arg_name} $value"
      else
        printf -v "$arg_name" '%s' "$value"
      fi
    done

    local synonyms="$(extract_synonyms "$all_args")"
    declare_namespace_var 'ARG_DEF_all_args'        "$all_args"
    declare_namespace_var 'ARG_DEF_no_value_args'   "$no_value_args"
    declare_namespace_var 'ARG_DEF_value_args'      "$value_args"
    declare_namespace_var 'ARG_DEF_required_args'   "$required_args"
    declare_namespace_var 'ARG_DEF_required_values' "$required_values"
    declare_namespace_var 'ARG_DEF_synonyms'        "$synonyms"
    declare_namespace_var 'ARG_DEF_ignore_errors'   "$ignore_errors"
  }

  parse() {

    while $# -gt 0; do
      arg="$1"
      shift

      # Determine argument type: a 1-dash argument, a 2-dash argument or a
      # positional argument.
      local arg_type
      if [[ "$arg" == "--"* ]]; then
        arg_type=2
      elif [[ "$arg" == "-"* ]]; then
        arg_type=1
      else
        [[ -n $prev_arg_name ]] && arg_type=-1 || arg_type=0
      fi

      if [ $arg_type -gt 0 ]; then
        local arg_name="$(extract_arg_name "$arg")"
        local arg_value="$(extract_arg_value "$arg")"
      else
        if [ $arg_type = -1 ]; then
          append_to_namespace_var 'arg_values' "$prev_arg_name" "$arg_name"
        else
          append_to_namespace_var 'pos_arg_values' "$arg"
        fi
      fi

    done

  }

  print_error() {
    local arg_name="$1"
    local arg_value="$2"
    local title="$3"
    echo -e "$(ind 4; color red)ERROR: $title"
    echo -e "$(ind 8; color bold) $arg_name == $arg_value$(color off)"
  }

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
  # This will be done via associative arrays - each key is the CLIARGS_NS of the
  # caller and each value is a pseudo-array string. Users of CliArgs() won't
  # have to worry about these details, this is all internal.
  #
  # _NS stands for NAMESPACE. The variable CLIARGS_NS can be provided by
  # user via the CALLER variable in front of the actual invocation of `CliArgs()`
  # or it'll be assigned automatically,
  # by fetching caller-script filename. If, for some, reason automatic assignment
  # fails, CLIARGS_NS will given the value of "default".
  #
  # CLIARGS_NS can only contain alphanumeric chars and _

  if [[ -z "$CALLER" ]]; then
    caller | grep -ovE '^[0-9]+' | grep -ovE '.[a-zA-Z]$' | sed 's/-/_/g' |
      read _ CLIARGS_NS # reads caller script name into the $CLIARGS_NS variable
  fi
  CLIARGS_NS="${CALLER:-default}"

  $CALL_NESTED $@
  return $?

}
