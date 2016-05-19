#!/usr/bin/ksh

arg1="config"

echo "arg1=$arg1"

if  [[ $arg1 != *deploy* ]] ; then
  echo "WARNING: Deployment to NSCs is SKIPPED because of missing or wrong options !!"
  exit
fi

echo "deployment starts ...."