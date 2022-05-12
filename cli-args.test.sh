#!/usr/bin/env bash

source cli-args.sh
source $BASHJAZZ_PATH/utils/assign_vars_from_out.sh
source $BASHJAZZ_PATH/utest/utest.sh

# This "sets the stage" for all unit test, as the will be checking against
# the same set of arguments and synonyms below.
CliArgs define \
  --no-value-args='a,l:list,u:list-updates,version,b' \
  --value-args='x,i:input-fn,o:output-fn,log-fn,y' \
  --required-args='a' \
  --required-values='input-fn' \
  --args='x,i:input-fn,o:output-fn,log-fn,y' > /dev/null

utest begin CliArgs \
'Parses and separates cli-args into positional & non-positional'

  utest begin declare_namespace_var
    assoc="greeting${CLIARGS_USEP}hello${CLIARGS_RSEP}"
    assoc+="address${CLIARGS_USEP}world${CLIARGS_RSEP}"
    CliArgs declare_namespace_var str_var 'hello world'
    CliArgs declare_namespace_var -a arr_var 'hello world'
    CliArgs declare_namespace_var -A assoc_var "$assoc"
    unset assoc

    utest assert "$str_var_FOR_default"  == 'hello world'
    utest assert "$(utest get_namespace_arr_item 0 arr_var)" == 'hello'
    utest assert "$(utest get_namespace_arr_item 1 arr_var)" == 'world'
    utest assert "$(utest get_namespace_arr_item greeting assoc_var)" == 'hello'
    utest assert "$(utest get_namespace_arr_item address  assoc_var)" == 'world'
  utest end declare_namespace_var

  utest begin append_to_declared_var_for_name
    utest cmd CliArgs declare_var_for_name str_var 'hello world'
    utest cmd CliArgs declare_var_for_name arr_var 'hello world'
    utest cmd CliArgs declare_namespace_var -A assoc_var \
      "greeting${CLI_ARGS_USEP} hello${CLIARGS_RSEP} address${CLI_ARGS_USEP} world"
    utest cmd CliArgs append_to_namespace_var
  utest end append_to_declared_var_for_name pending

  #utest begin define \
  #'Defines the rules according to which arguments are parsed and accepted/rejected'
    #utest assert "$ARG_DEF_ignore_errors_FOR_default" == 'yes'
    #utest assert "$ARG_DEF_all_args_FOR_default" == \
      #'a l:list u:list_updates version b x i:input_fn o:output_fn log_fn y'
    #utest assert "$ARG_DEF_no_value_args_FOR_default" == \
      #'a list list_updates version b'
    #utest assert "$ARG_DEF_value_args_FOR_default" == \
      #'x input_fn output_fn log_fn y'
    #utest assert "$ARG_DEF_required_args_FOR_default" == 'a'
    #utest assert "$ARG_DEF_synonyms_FOR_default" == \
      #'a l u version b x i o log_fn y'
  #utest end define pending

  #utest begin parse

    #utest begin with_correct_args
      #utest cmd CliArgs parse -a -l --list-updates --version \
        #-i file.txt --output-fn=output.txt
      #utest assert "${ARGS_VALUES_FOR_default[a]}"            == 'yes'
      #utest assert "${ARGS_VALUES_FOR_default[list]}"         == 'yes'
      #utest assert "${ARGS_VALUES_FOR_default[list_updates]}" == 'yes'
      #utest assert "${ARGS_VALUES_FOR_default[input.txt]}"    == 'input.txt'
      #utest assert "${ARGS_VALUES_FOR_default[output.txt]}"   == 'output.txt'
    #utest end with_wrong_args

    #utest begin with_uknown_args
    #utest end with_uknown_args pending

    #utest begin with_wrong_arg_values
    #utest end with_wrong_arg_values pending

    #utest begin without_required_arg
    #utest end without_required_arg pending

  #utest end parse

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

  utest end get_name pending

  ######################### PENDING ##############################
  utest begin get_value
    utest begin two_dash_argument \
    'Gets value from --two-dash-arg, sets to "true" if no value provided after ='
      utest cmd CliArgs get_value_for \
        two-dash-arg '--two-dash-arg="value 1" --arg2=1'
      utest assert "$UTOUT" == 'value 1'
    utest end two_dash_argument pending


    utest begin single_dash_argument \
      'Gets value (or sets it to "true") from a single-dash argument, such as -a'
      utest cmd CliArgs get_value_for t '-t "value 1" -s something_else'
      utest assert "$UTOUT" == 'value 1'
    utest end single_dash_argument pending
  utest end get_value

  utest begin ignoring_unknown_args \
  "doesn't throw error when --ignore-unknown-args flag is present"
    utest add_cmd CliArgs parse -x --input-fn=filename.txt
    utest assert "$UTERR" is blank
  utest end ignoring_uknown_args pending


utest end CliArgs
