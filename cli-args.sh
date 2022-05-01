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
  local NAME="$CALLER"
  if [[ -z "$NAME" ]]; then
    caller | grep -ovE '^[0-9]+' | grep -ovE '.[a-zA-Z]$' | \
      read _ NAME # reads caller script name into the $NAME variable
    NAME="${NAME:-default}"
  fi

  # This is a unique global associative array which stores all the information
  # about both arguments definitions (or rules: which arguments are required,
  # which are allowed, but optional etc.) with each item of that array being
  # a pseudo-array - a string separated by a special $ARG_ARRAY_SEPARATOR
  # These pseudo-arrays will be used by other nested functions of CliArgs()
  # to return whatever the user requests.
  declare -gA "ARG_DATA_FOR_${NAME}"

  strip_from_dashes() {
    echo "$1" | sed 's/--?//'
  }

  extract_synonyms() {
    echo $(echo "${@}"              | \
      grep -oE '[a-zA-Z]:[a-zA-Z]+' | \
      sed -E 's/:[^ ]+/ /g')
  }

  get_long_name_for_synonym() {
    local arg_name=$1
    shift
    echo "$@" | grep -o "$arg_name:[^ ]*" | grep -o ':[^: ]*' | cut -c2-
  }

  get_value_for() {
    return 0
  }

  # Prints data held in keys from ARG_DATA_FOR_$NAME associative array.
  # Used by define() and parse() to print that info out. Why print when
  # data is already stored in a global variable? At this point, it's for
  # unit-testing, because $BASHJAZZ_PATH/utest uses subroutines, which means
  # global variables stay within their confines and cannot be accessed
  # in unit tests. Printing them out solves this issue.
  print_args_data() {
    local var_names="$@"
    # TODO: print argument data from the global associative array ARG_DATA_FOR_$NAME
  }

  define() {

    local -A args
    local -a synonyms

    local args[value]="$VALUE_ARGS"
    local args[no_value]="$NO_VALUE_ARGS"
    local args[default_value]="$DEFAULT_VALUE_ARGS"
    local args[required]="$REQUIRED_ARGS"

    for k in "${!args[@]}"; do
      synonyms=( "${synonyms[@]}" "$(extract_synonyms ${args[$k]})" )

      # The next line of code removes the ":" character, which means we only
      # keeps the two-dash argument names in these variables or,
      # if a cli-arg only has a one-dash version, then that's the one that will
      # be kept. This is fine, because get_value_for() will take either a
      # synonym or an actual name and return a value we'll extract later on.


      args[$k]="$(echo "${args[$k]}" | sed -E 's/(^| )[a-zA-Z]:/ /g')"
      # TODO: assign this value above to the global associate
      # array ARG_DATA_FOR_$NAME. Possible solution:
      #
      #   IFS= read -r -d '' "ARG_DATA_FOR_$NAME[$k]" <<< "${args[$k]}"

      # TODO MAYBE: call print_args_data() with proper argument names

    done

  }

  parse() {

    local name="${1:-$NAME}"

    while $# -gt 0; do
      arg="$1"
      shift

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

      # TODO MAYBE: call print_args_data() with proper argument names
    done

  }


  ########### TODO: part of that code should end up in the parse() function
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

      if [[ -z "$arg_allowed" ]] && [[ -z "$IGNORE_ARG_ERRORS" ]]; then
        >&2 echo -e "${Red}Argument not allowed: ${Yellow}--$arg_name"
        exit 1
      fi

      if [[ -n "$(Array_contains $arg_name ${VALUE_REQUIRED_ARGS[@]})" ]]; then
        arg_value="$(echo "$arg" | grep -voE '\-\-[a-z0-9]=')"
        NAMED_ARGS["$arg_name"]="$arg_value"
      elif [[ -n "$(Array_contains $arg_name ${VALUELESS_ARGS[@]})" ]]; then
        NAMED_ARGS["$arg_name"]="$ARG_VALUE_TRUE"
      elif [[ -z "$IGNORE_ARG_ERRORS" ]]; then
        >&2 echo -e "Argument requires value: ${Yellow}--$arg_name${Red}\n"
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

      if [[ -z "$arg_allowed" ]] && [[ -z "$IGNORE_ARG_ERRORS" ]]; then
        echo -e "Argument not allowed: -${Yellow}$arg_name${Red}\n"
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
  #########################################################################

  # ATTENTION: here the program will exit if a non-existent nested function
  # was called.
  $CALL_NESTED $@
  exit $?

}
