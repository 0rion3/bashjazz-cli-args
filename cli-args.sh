#!/usr/bin/env bash
source $BASHJAZZ_PATH/utils/array.sh
source $BASHJAZZ_PATH/utils/formatting.sh
source $BASHJAZZ_PATH/utils/quoted_string.sh

declare -g RSEP="" # record separator - \x1E
declare -g USEP="" # unit separator   - \x1F
NULL_SYM='␀'

CliArgs() {

  ########## NAMESPACE VARIABLES, EMULATING ARRAYS & ##########
  ##########          ASSOCIATIVE ARRAYS             ##########
  #
  # This code should probably be extracted into a separate
  # library. It's got little to do with CliArgs itself, but
  # but it simplifies working with dynamic variable names,
  # when variables are Arrays or Associative arrays. And it
  # generally simplifies things in terms of working with these
  # two data structures, being a de-facto alternative
  # implementation for the them.
  #
  # It works best for Arrays and Associative Arrays, but isn't
  # good if values contain extra spaces, which it ignores.
  # If you need to account for extra spaces, use something else.

  declare_namespace_var() {
    if [[ "$1" == "-"* ]]; then
      local var_flag="$1 "
      shift
    fi
    local var_name="$1_FOR_$CLIARGS_NS"
    shift
    printf -v "$var_name" '%s' "$var_flag$(echo "${@}" | xargs)"
  }

  append_to_namespace_var() {
    var_name="$1_FOR_$CLIARGS_NS"
    shift

    local var_addition="$(echo "$@" | xargs)"
    local var_type="$(echo "${!var_name}" | grep -oE '^-[a-zA-Z]')"

    local var_value
    if [[ $var_type == '-A' ]]; then
      var_value="${!var_name}$var_addition"
    elif [[ $var_type == '-a' ]]; then
      var_value="${!var_name} $var_addition"
    else
      var_value="${!var_name} ${@}"
    fi
    printf -v "$var_name" '%s' "$var_value"
  }

  # $1 = arr_name (without the namespace, example: ARG_DEF_all_args)
  # $2 = arr_index (integer)
  get_namespace_var() {
    var_name="${1}_FOR_${CLIARGS_NS}"

    if [[ "${!var_name}" == "-A"* ]]; then
      local i="$2"
      if [[ -n $2 ]]; then
        echo "${!var_name}" | \
          grep -oE "${i}${USEP}[^${RSEP}]+" | \
          sed "s/${i}${USEP}//" | xargs
      else
        echo "${!var_name}" | xargs
      fi
    elif [[ "${!var_name}" == "-a"* ]]; then 
      local arr=( $(echo "${!var_name}" ) )
      if [[ -n $2 ]]; then
        local i=$(($2+1)) # Because 0 is -a
        echo "${arr[$i]}" | xargs
      else
        echo "${arr[@]}" | sed 's/^-[a-zA-Z]//' | xargs
      fi
    else
      echo "${!var_name}"
    fi

  }

  namespace_var_contains() {
    local var_name="${1}_FOR_${CLIARGS_NS}"
    local var_value="${!var_name}"
    if [[ "$var_value" =~ (^| )$2( |$) ]]; then
      echo "$2" && return 0
    else
      echo "" && return 1
    fi
  }

  ##########               END OF                    ##########
  ########## NAMESPACE VARIABLES, EMULATING ARRAYS & ##########
  ##########          ASSOCIATIVE ARRAYS             ##########

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
    local arg_name=$(echo "$1" | sed 's/^--//' | sed 's/^-//g' | sed 's/-/_/g')

    local names=($(
      echo "$(get_namespace_var ARG_DEF_all_args)" | sed -E 's/[a-zA-Z0-9_]+[:]//g'
    ))
    local synonyms=( $(get_namespace_var ARG_DEF_synonyms) )

    local result="$(echo "${names[@]}"   | \
      grep -oE "(^|\s|:)$arg_name(\s|$)" | \
      sed 's/^://')"

    if [[ -z "$result" ]]; then
      if [[ -n "$(Array_contains $arg_name ${synonyms[@]})" ]]; then
        local item_index="$(Array_get_index_for $arg_name ${synonyms[@]})"
        result="${names[$item_index]}"
      fi
    fi

    echo "$result" | xargs # again, xargs here is to remove trailing whitespace

  }

  get_value() {
    local arg_name="$(get_name "$1")"
    local result=$?
    if [[ $result == 0 ]]; then
      echo "$(get_namespace_var 'ARG_VALUES' $arg_name)"
    fi
    return $result
  }

  arg_present?() {
    local all_provided_args="$(get_namespace_var 'ARG_VALUES')"
    local matched_arg="$(echo "$all_provided_args" | sed 's/^-A //' | \
      grep -oE "(^|$RSEP)$1$USEP")"
    if [[ -n "$matched_arg" ]]; then
      echo -n "yes" && return 0
    else
      echo -n "" && return 1
    fi
  }

  arg_known?() {
    local all_known_args="$( \
      get_namespace_var ARG_DEF_all_args | sed 's/:/ /g' | sed 's/-/_/g')"
    if [[ -n "$(Array_contains $1 $all_known_args)" ]]; then
      echo "yes" && return 0
    else
      echo "" && return 1
    fi
  }

  arg_has_value?() {
    test -n "$(get_value $1)" && return 0 || return 1
  }

  extract_arg_name() {
    echo "$1" | grep -oE '^\-\-[a-zA-Z0-9\-]+=?' | \
      sed 's/^--//' | sed 's/-/_/g' | sed 's/=$//'
  }

  extract_arg_value() {
    echo "$1" | \
      sed -E "s/--[a-z\-]+=?//g" | \
      sed 's/,/ /g'              | \
      sed 's/-/_/g'
  }

  pos_arg() {
    local pos_args=( $(get_namespace_var 'POS_ARG_VALUES') )
    echo "${pos_args[$1]}"
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
        if [[ "$arg_name" =~ ^(no_)?value_args$ ]]; then
          all_args+="$value "
        fi
        value="$(echo "$value" | sed -E 's/(^| )[a-zA-Z0-9]+:/ /g')"
        printf -v "$arg_name" '%s' "${!arg_name} $value"
      else
        printf -v "$arg_name" '%s' "$value"
      fi

    done

    local synonyms="$(extract_synonyms "$all_args")"
    declare_namespace_var -a 'ARG_DEF_all_args'        "$all_args"
    declare_namespace_var -a 'ARG_DEF_no_value_args'   "$no_value_args"
    declare_namespace_var -a 'ARG_DEF_value_args'      "$value_args"
    declare_namespace_var -a 'ARG_DEF_required_args'   "$required_args"
    declare_namespace_var -a 'ARG_DEF_required_values' "$required_values"
    declare_namespace_var -a 'ARG_DEF_synonyms'        "$synonyms"
    declare_namespace_var -a 'ARG_DEF_ignore_errors'   "$ignore_errors"
  }

  parse() {

    declare_namespace_var -A ARG_VALUES
    declare_namespace_var -a POS_ARG_VALUES
    local prev_arg_name
    for arg in "${@}"; do

      # Determine argument type: a 1-dash argument, a 2-dash argument or a
      # positional argument.
      local arg_type
      if [[ "$arg" == "--"* ]]; then
        arg_type=2
      elif [[ "$arg" == "-"* ]]; then
        arg_type=1
      else
        arg_type=0
      fi

      local arg_name
      local arg_value

      if [ $arg_type -gt 0 ]; then

        if [ $arg_type = 1 ]; then
          arg_name="$(get_name $arg)"
          if [[ -n $arg_name ]]; then
            if [[ -n "$(namespace_var_contains ARG_DEF_value_args $arg_name)" ]]; then
              prev_arg_name="$(get_name $arg)"
              continue
            else
              arg_value="$ARG_VALUE_TRUE"
            fi
          fi
        elif [ $arg_type = 2 ]; then
          arg_name="$(get_name $(extract_arg_name "$arg"))"
          if [[ -n "$(namespace_var_contains ARG_DEF_value_args $arg_name)" ]]; then
            arg_value="$(extract_arg_value "$arg")"
          else
            arg_value="${arg_value:-$ARG_VALUE_TRUE}"
          fi
          arg_name="${arg_name:-$(echo "$arg" | \
            sed 's/^--//' | sed 's/-/_/g' | sed 's/=$//')}"
        fi

      else
        if [[ -n $prev_arg_name ]]; then
          local arg_name="$prev_arg_name"
          local arg_value="$arg"
        fi
      fi

      local arg_name="${arg_name:-$prev_arg_name}"

      # Checking whether a given argument or its value is valid.
      # Being valid right now basically means whether the argument
      # is allowed and whether it requires a value. There's one more check
      # outside of this `for` loop, which checks if required arguments
      # are present at all - but that's about it for now. Further rules for
      # argument values shall be implemented by CliArg users in their
      # respective Bash scripts.
      #
      # All errors are ignored if `CliArgs define` was called
      # with `--ignore-errors`.
      if [[ -n $arg_name ]] && \
         [[ -z "$(namespace_var_contains ARG_DEF_ignore_errors)" ]]; then

        # 1. Check if it's on the list of accepted arguments
        if [[ -z "$(arg_known? $arg_name)" ]]; then
          print_error $arg_name "_" "unknown argument" && return 1
        fi

        # 2. Check if argument requires value and it is provided
        if [[ "$(namespace_var_contains ARG_DEF_required_values $arg_name)" ]] &&
           [[ -z "$arg_value" ]]; then
           print_error $arg_name $NULL_SYM \
             "missing required value for argument" && return 1
        fi

      fi

      if [[ -n $prev_arg_name ]] || [ $arg_type -gt 0 ]; then
        append_to_namespace_var \
          'ARG_VALUES' "$arg_name${USEP}$arg_value${RSEP}"
        unset prev_arg_name
      else
        append_to_namespace_var 'POS_ARG_VALUES' "$arg"
      fi
      unset arg_value

    done

    if [[ -z "$(namespace_var_contains ARG_DEF_ignore_errors)" ]]; then
      local required_args=( $(get_namespace_var ARG_DEF_required_args) )
      for r in "${required_args[@]}"; do
        if [[ -z "$(arg_present? "$r")" ]]; then
          print_error "$r" "$NULL_SYM" "required argument is missing"
          return 1
        fi
      done
    fi

  }

  print_error() {
    local arg_name="$1"
    local arg_value="$2"
    local title="$3"
    local SEP="\n$(ind 8)"
    if [[ $arg_value == $NULL_SYM ]]; then
      arg_value="is blank"
    elif [[ $arg_value == "_" ]]; then
      arg_value=""
      SEP=": "
    else
      arg_value="== $arg_value"
    fi
    >&2 echo -en  "\n$(ind 4; color red)$title"
    >&2 echo -en "${SEP}$(color bold)$arg_name$(color off; color red) $arg_value"
    >&2 echo -e  "$(color off)"
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
