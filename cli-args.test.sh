#!/usr/bin/env bash

source $BASHJAZZ_PATH/utest/utest.sh
source $BASHJAZZ_PATH/utils/assign_vars_from_out.sh
source cli-args.sh

CliArgs "$@"
exit

utest begin CliArgs \
'Parses and separates cli-args into positional & non-positional'

  utest begin extract_allowed_args \
  'Extracts names of allowed short (-s) and --long arguments.'
    utest cmd CliArgs extract_allowed_args \
    value-required --value-required-args=a:arg1,b:arg2,arg3,x,y,z \
                   --something-else=something_elses_value
    utest assert "$UTOUT" == 'a:arg1 b:arg2 arg3 x y z'
  utest end extract_allowed_args


  utest begin extract_allowed_args_synonyms \
  'Separate one letter synonyms of required and valueless args into ARG_SYNONYMS'
    utest cmd CliArgs extract_allowed_args_synonyms \
      'a b u:url o:output-fn encoding x y z'
    utest assert "$UTOUT" == 'u o'
  utest end extract_allowed_args_synonyms

  utest begin get_long_name_for_synonym
    utest cmd CliArgs get_long_name_for_synonym 'l l:long-arg v:version'
    utest assert "$UTOUT" == 'long-arg'
  utest end get_long_name_for_synonym

  utest begin get_value_for_TWO_DASH_ARG \
  'Gets value from --two-dash-arg, sets to "true" if no value provided after ='
    utest cmd CliArgs get_value_for \
      two-dash-arg '--two-dash-arg="value 1" --arg2=1'
    utest assert "$UTOUT" == 'value 1'
  utest end get_value_for_TWO_DASH_ARG

  utest begin get_value_for_ONE_DASH_ARG \
  'Gets value from '
    utest cmd CliArgs get_value_for t '-t "value 1" -s something_else'
    utest assert "$UTOUT" == 'value 1'
  utest end get_value_for_ONE_DASH_ARG

  utest begin ignoring_unknown_args \
  "doesn't throw error when --ignore-unknown-args flag is present"
    utest cmd CliArgs --valueless-args=a,b,c,hello --ignore-arg-errors -x --howdy
    utest assert "$UTERR" is blank
  utest end ignoring_uknown_args

  utest begin MAIN
    utest cmd CliArgs --valueless-args=a,l:list,u:list-updates,version,b \
                      --value-required-args=x,i:input-fn,o:output-fn,log-fn,y \
                      --ignore-arg-errors \
                      -a --list -u --version -b \
                      -x 1 -i input.txt --output-fn=output.txt --log-fn=my.log \
                      positional_arg1

    echo "$UTOUT" | assign_vars_from_out
    utest assert "$VALUELESS_ARGS"      == 'a list list-updates version b'
    utest assert "$VALUE_REQUIRED_ARGS" == 'x input-fn output-fn log-fn y'
    utest assert "$ARG_SYNONYMS"        == 'i o l u'
    utest assert "$POS_ARGS"            == 'positional_arg1'
    utest assert "$NAMED_ARGS"          == ''
  utest end MAIN


utest end CliArgs
