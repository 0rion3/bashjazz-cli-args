#!/usr/bin/env bash
source $BASHJAZZ_PATH/utils/array.sh

# WARNING: this script does not support whitespace in argument values

declare -ga VALUE_REQUIRED_ARGS
declare -ga VALUELESS_ARGS
declare -ga ARG_SYNONYMS
declare -ga POS_ARGS
declare -gA NAMED_ARGS

# To Separate short one-dash args from their long two-dash arguments
# equivalents, synonyms are created by using ":" character when describing
# attributes, with the short, one letter synonym being written first, then colon,
# then the longer name for the attribute. For instance, if we call the current
# function with this argument:
#
#     --valueless-args=l:list,u:list-updates
#
# then `-l` shall be an alias for `--list` and `-u` shall be an alias
# for `--list-updates`. Therefore, we need to clearly distinguish them,
# but also make sure that the code below that goes through the actual args
# passed understands they are synonyms.



# ATTENTION: the following function is called automatically upon sourcing
#            this file - it will be called on the last line of this script.
CliArgs() {

  # For unit-test compliance and allowing to unit-test nested functions,
  # (but can also be used in other cases we allow to call each individual
  # function from the nested functions in CliArgs. For this to work,
  # the first argument should be -n function_name (-c stands for 'call').
  # The actual calls will be done after function declarations.
  # Here, we need to to shift the first argument two arguments
  # (-n and its value) if they're found.
  if test $1 = '-c'; then
    local CALL_NESTED="$2"
    shift 2
  fi

  local INITIAL_ARGS="$@"

  local ARG_VALUE_TRUE="${ARG_VALUE_TRUE:-yes}"
  local ARG_VALUE_FALSE="${ARG_VALUE_FALSE:-no}"

  extract_allowed_args() {
    local arg_type="$1"
    shift
    echo "$@"                                  | \
      grep -oE "\-\-$arg_type-args=[^ ]+"      | \
      sed -E 's/.+=//'                         | \
      sed 's/,/ /g'
  }

  extract_allowed_args_with_synonyms() {
    for a in "${@}"; do
      if [[ "$a" == *":"* ]]; then echo -n "$a "; fi
    done
  }

  get_long_arg_name() {
    local short_name=$1
    local both_names="$2"
    echo "${both_names:-${ARG_SYNONYMS[@]}}" | sed -E "s/^$1://"
  }

  get_value_for() {
    local result="${VALUE_REQUIRED_ARGS[$1]}"
    echo "$result"
    #echo "${result:-${VALUELESS_ARGS[$1]}}"
  }

  # ATTENTION: here the program will exit if the wrong an individual nested 
  # is being called (which would be the case with unit testing).
  test -n $CALL_NESTED && $CALL_NESTED $@ && exit $?

  # This is not the final result of extracting names, we need them as strings
  # to easily pass to another function, which extracts synonyms and finalizes
  # the process VALUE_REQUIRED_ARGS and VALUELESS_ARGS
  VALUE_REQUIRED_ARGS=( $(extract_allowed_args 'value-required' $INITIAL_ARGS) )
  VALUELESS_ARGS=( $(extract_allowed_args 'valueless' $INITIAL_ARGS) )

  # The function called below only returns something if
  # the respective variable isn't empty (meaning, the --value-required-args
  # and/or --valueless-args arguments were provided and need to be removed
  # from $INITIAL_ARGS.
  local arg_synonyms1=( extract_allowed_args_with_synonyms "${VALUE_REQUIRED_ARGS[@]}")
  local arg_synonyms2=( extract_allowed_args_with_synonyms "${VALUELESS_ARGS[@]}"     )
  declare -g ARG_SYNONYMS=( "${arg_synonyms1[@]}" "${arg_synonyms2[@]}" )

  local one_dash_arg_name

  for arg in "${@}"; do

    # Two-dash arguments - it's a long argument with the value being provided
    # after the "=" character or assigned from $ARG_TRUE_VALUE (just because of
    # this argument's mere presence).

    if [[ "$arg" == "--"* ]]; then
      # Remove the two leading dashes, replace = with a space so we can convert an argument
      # into a two item-array where the 1st item is the name of the argument and the 2nd argument
      # is its value.
      arg_name="$(echo "$arg" | grep -oE '\-\-[a-z][a-z0-9\-]+' | sed 's/^--//')"

      local arg_allowed="$(
        Array_contains $arg_name "${VALUE_REQUIRED_ARGS[@]}" || \
        Array_contains $arg_name ${VALUELESS_ARGS[@]}
      )"

      if [[ -z "$arg_allowed" ]]; then
        echo "  Bad argument: $arg_name"
        exit 1
      fi

      if [[ -n "$(Array_contains $arg_name ${VALUE_REQUIRED_ARGS[@]})" ]]; then
        arg_value="$(echo "$arg" | grep -voE '\-\-[a-z0-9]=')"
        NAMED_ARGS["$arg_name"]="$arg_value"
      elif [[ -n "$(Array_contains $arg_name ${VALUELESS_ARGS[@]})" ]]; then
        NAMED_ARGS["$arg_name"]="$ARG_VALUE_TRUE"
      else
        echo "  Bad argument: --$arg_name"
        exit 1
      fi

    # One dash arguments such as `-c` can also require value, but,
    # technically, the value for such an argument would be a separate item
    # in the $INITIAL_ARGS array - the next item after the on-dash argument
    # itself. Or, alternatively, if the one-dash argument is immediately
    # followed by by a number, such as it would be in `tail -n1`,
    # we use that number
    elif [[ $arg == "-"* ]]; then

      arg_name="$(echo "$arg" | grep -oE '[a-zA-Z]' )"

      local arg_allowed="$(
        Array_contains $arg_name ${VALUE_REQUIRED_ARGS[@]} || \
        Array_contains $arg_name ${VALUELESS_ARGS[@]}
      )"

      if [[ -z "$arg_allowed" ]]; then
        echo "  Bad argument: $arg_name"
        exit 1
      fi

      arg_value="$(echo "$arg" | grep -Eo '[0-9]+$')"

      if [[ -n "$(Array_contains $arg_name ${VALUE_REQUIRED_ARGS[@]})" ]]; then 
        if [[ -n "$arg_value" ]]; then
          NAMED_ARGS[$arg_name]="$arg_name"
        else
          one_dash_arg_name="$arg_name"
        fi
      else
        NAMED_ARGS[$arg_name]="$ARG_VALUE_TRUE"
      fi

    # Adding value for the one_dash _argument.
    elif [[ -n "$one_dash_arg_name" ]]; then
      NAMED_ARGS[$one_dash_arg_name]="$arg"
      unset one_dash_arg_name
    # Everything else is considered a positional argument
    else
      POS_ARGS+=("$arg")
    fi

  done

}
