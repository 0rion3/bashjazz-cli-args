#!/usr/bin/env bash

source cli-args.sh
source $BASHJAZZ_PATH/utils/assign_vars_from_out.sh
source $BASHJAZZ_PATH/utest/utest.sh

# This "sets the stage" for all unit test, as the will be checking against
# the same set of arguments and synonyms below.

CliArgs define \
  --no-value-args='a,l:list,u:list-updates,version,b' \
  --value-args='x,i:input-fn,o:output-fn,log-fn,y,e:encrypt,m:mountpoint,d' \
  --required-args='input-fn' \
  --required-values='input-fn' \
  --default-values='encrypt:yes,device:/dev/sde1,mountpoint:/mnt/abc1'

utest begin CliArgs \
'Parses and separates cli-args into positional & non-positional'

  utest begin namespace_vars

    assoc="greeting${USEP}hello${RSEP}"
    assoc+="address${USEP}world${RSEP}"
    CliArgs declare_namespace_var str_var 'hello world'
    CliArgs declare_namespace_var -a arr_var 'hello world'
    CliArgs declare_namespace_var -A assoc_var "$assoc"

    utest begin declaration
      utest assert "$(utest namespace_var_value ARG_DEF_default_values)" == \
        'encrypt:yes device:/dev/sde1 mountpoint:/mnt/abc1'
      utest assert "$(utest namespace_var_value str_var)"   == 'hello world'
      utest assert "$(utest namespace_var_value arr_var 0)" == 'hello'
      utest assert "$(utest namespace_var_value arr_var 1)" == 'world'
      utest assert "$(utest namespace_var_value assoc_var greeting)" == 'hello'
      utest assert "$(utest namespace_var_value assoc_var address)" == 'world'
    utest end declaration

    utest begin appending_value
      CliArgs append_to_namespace_var str_var 'from utest' # space is intentional
      CliArgs append_to_namespace_var arr_var 'from utest'
      CliArgs append_to_namespace_var assoc_var "from${USEP}utest"
      utest assert "$(utest namespace_var_value str_var)"   == 'hello world from utest'
      utest assert "$(utest namespace_var_value arr_var 2)" == 'from'
      utest assert "$(utest namespace_var_value arr_var 3)" == 'utest'
      utest assert "$(utest namespace_var_value assoc_var from)" == 'utest'
    utest end appending_value

    unset assoc

  utest end namespace_vars

  utest begin get_name \
  'Given the synonym or original name in $1 to get_name(), echo original arg name'

    utest begin from_the_same_name \
    'Prints the original arg name, the same value as $1 given to get_name()'

      # Case 1: list is itself the actual long name of the argument,
      # CliArgs's `get_name()` must simply return the same value
      # as it's been passed.
      utest cmd CliArgs get_name 'list'
      utest assert "$UTOUT" == 'list'

      # Case 2: argument 'y' has no long-version, thus it isn't a synonym.
      # even though it may appear to be so.
      utest cmd CliArgs get_name 'y'
      utest assert "$UTOUT" == 'y'

      # Case 3: arg name contains a dash "-" char. CliArgs() stores values for
      # arguments in a Bash associative array, therefore its keys - which are
      # argument names - mustn't contain dashes; get_name(), therefore,
      # replaces dashes with underscores "_" upon returning the argument name.
      utest cmd CliArgs get_name 'input-fn'
      utest assert "$UTOUT" == 'input_fn'
    utest end from_the_same_name

    utest begin from_synonym \
    'Prints the original arg name given synonym provided as $1 to get_name()'

      # Case1: argument 'l' has a long-version 'list', thus it is a synonym.
      utest cmd CliArgs get_name 'l'
      utest assert "$UTOUT" == "list"

    utest end from_synonym

  utest end get_name

  utest begin define \
  'Defines the rules according to which arguments are parsed and accepted/rejected'
    utest assert "$(utest namespace_var_value ARG_DEF_all_args)" == \
      'a l:list u:list_updates version b x i:input_fn o:output_fn log_fn y e:encrypt m:mountpoint d'
    utest assert "$(utest namespace_var_value ARG_DEF_no_value_args)" == \
      'a list list_updates version b'
    utest assert "$(utest namespace_var_value ARG_DEF_value_args)" == \
      'x input_fn output_fn log_fn y encrypt mountpoint d'
    utest assert "$(utest namespace_var_value ARG_DEF_required_args)" == 'input_fn'
    utest assert "$(utest namespace_var_value ARG_DEF_synonyms)" == \
      'a l u version b x i o log_fn y e m d'
  utest end define

  utest begin parse

    utest cmd CliArgs parse \
      -a -l --list-updates --version --mountpoint \
      -i input.txt --output-fn=output.txt pos_value_1 pos_value_2

    utest begin get_value
      utest begin two_dash_argument \
      'Gets value for --two-dash-arguments'
        utest cmd CliArgs get_value list_updates
        utest assert "$UTOUT" == 'yes'
        utest cmd CliArgs get_value output_fn
        utest assert "$UTOUT" == 'output.txt'
      utest end two_dash_argument


      utest begin single_dash_argument \
      'Gets value for -s single dash arguments'
        utest cmd CliArgs get_value list
        utest assert "$UTOUT" == 'yes'
        utest cmd CliArgs get_value input_fn
        utest assert "$UTOUT" == 'input.txt'
      utest end single_dash_argument
    utest end get_value

    utest begin get_positional_arg_value
      utest cmd CliArgs pos_arg 0
      utest assert "$UTOUT" == "pos_value_1"
      utest cmd CliArgs pos_arg 1
      utest assert "$UTOUT" == "pos_value_2"
    utest end get_positional_arg_value

    utest begin assigns_default_values_to_args \
    "args listed under --value-required-args get a default value if none provided"
      utest cmd CliArgs get_value mountpoint
      utest assert "$UTOUT" == "/mnt/abc1"
    utest end

    utest begin with_correct_args
      utest assert "$(utest namespace_var_value ARG_VALUES a)"            == 'yes'
      utest assert "$(utest namespace_var_value ARG_VALUES list)"         == 'yes'
      utest assert "$(utest namespace_var_value ARG_VALUES list_updates)" == 'yes'
      utest assert "$(utest namespace_var_value ARG_VALUES input_fn)"     == 'input.txt'
      utest assert "$(utest namespace_var_value ARG_VALUES output_fn)"    == 'output.txt'
      utest assert "$(utest namespace_var_value POS_ARG_VALUES 0)"        == 'pos_value_1'
      utest assert "$(utest namespace_var_value POS_ARG_VALUES 1)"        == 'pos_value_2'
    utest end with_wrong_args

    utest begin with_uknown_args
      utest cmd CliArgs parse --input-fn=file.txt --unknown
      utest assert --error "$UTERR" contains "unknown argument"
    utest end with_uknown_args

    utest begin with_required_value_missing

      utest cmd CliArgs parse --input-fn --inknown
      utest assert --error "$UTERR" contains "missing required value for argument"
    utest end with_wrong_arg_values

    utest begin with_required_arg_missing
      utest cmd CliArgs parse -y
      utest assert --error "$UTERR" contains "required argument is missing"
    utest end without_required_arg

    utest begin ignoring_errors \
    "doesn't throw error when --ignore-errors flag is present"
      utest cmd CliArgs parse -x --input-fn=filename.txt
      utest assert "$UTERR" is blank
    utest end ignoring_errors

  utest end parse

utest end CliArgs
