#!/usr/bin/env bash

source $BASHJAZZ_PATH/utest/utest.sh
source $BASHJAZZ_PATH/utils/assign_vars_from_out.sh
source cli-args.sh

utest begin CliArgs \
'Parses and separates cli-args into positional & non-positional'

  utest begin extract_allowed_args \
  'Extracts names of allowed short (-s) and --long arguments.'
     utest cmd CliArgs -c extract_allowed_args \
     value-required --value-required-args=a:arg1,b:arg2,arg3,x,y,z \
                    --something-else=something_elses_value
     utest assert "$UTOUT" == 'a:arg1 b:arg2 arg3 x y z'
  utest end extract_allowed_args


  utest begin extract_allowed_args_synonyms \
  'Separate one letter synonyms of required and valueless args into ARG_SYNONYMS'
    utest cmd CliArgs -c extract_allowed_args_synonyms \
      a b u:url o:output-fn encoding x y z
      utest assert "$UTOUT" == 'u o'
  utest end extract_allowed_args_synonyms

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
