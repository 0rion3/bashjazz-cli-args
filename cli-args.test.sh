#!/usr/bin/env bash

source $BASHJAZZ_PATH/utest/utest.sh
source $BASHJAZZ_PATH/utils/assign_vars_from_out.sh
source cli-args.sh

utest begin CliArgs \
'Parses and separates cli-args into positional & non-positional'

  utest begin define \
  'Defines the rules according to which arguments are parsed and accepted/rejected'
    utest cmd CliArgs define \
      --no-value-args='a,l:list,u:list-updates,version,b' \
      --value-args='x,i:input-fn,o:output-fn,log-fn,y' \
      --ignore-errors
    echo "$UTOUT" | assign_vars_from_out
    utest assert "$ARG_DEF_no_value_args_FOR_default" == 'a list list-updates version b'
    utest assert "$ARG_DEF_value_args_FOR_default"    == 'x input-fn output-fn log-fn y'
    utest assert "$ARG_DEF_ignore_errors_FOR_default" == 'yes'
    utest assert "$ARG_DEF_synonyms_FOR_default"      == \
      'a l u version b x i o log-fn y'
  utest end define

  #utest begin parse

    #utest begin with_correct_args
      #utest add_cmd CliArgs define \
        #--no-value-args='a,l:list,u:list-updates,version,b' \
        #--value-args='x,i:input-fn,o:output-fn,log-fn,y' \
        #--required-args='input-fn' \
      #utest add_cmd CliArgs parse -a -l --list-updates --version \
        #-i file.txt 'positional argument value'
      #utest cmd
      #echo "$UTOUT" | assign_vars_from_out
    #utest end with_wrong_args

    #utest begin with_wrong_args
    #utest end with_wrong_arg_values pending

    #utest begin without_required_arg
    #utest end without_required_arg pending

  #utest end parse

  #utest begin ignoring_unknown_args \
  #"doesn't throw error when --ignore-unknown-args flag is present"
    #utest add_cmd CliArgs define \
      #--ignore-arg-errors
      #--no-value-args=a,b,c,hello
    #utest add_cmd CliArgs parse -x --howdy
    #utest assert "$UTERR" is blank
  #utest end ignoring_uknown_args

  #utest begin get_value_for_TWO_DASH_ARG \
  #'Gets value from --two-dash-arg, sets to "true" if no value provided after ='
    #utest cmd CliArgs get_value_for \
      #two-dash-arg '--two-dash-arg="value 1" --arg2=1'
    #utest assert "$UTOUT" == 'value 1'
  #utest end get_value_for_TWO_DASH_ARG
  #exit

  #utest begin get_value_for_ONE_DASH_ARG \
  #'Gets value from '
    #utest cmd CliArgs get_value_for t '-t "value 1" -s something_else'
    #utest assert "$UTOUT" == 'value 1'
  #utest end get_value_for_ONE_DASH_ARG


utest end CliArgs
