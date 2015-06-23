#!/bin/bash

days_to_keep_nightlies=21
days_to_keep_storage=5
days_to_keep_tests=3

upstream=/home/appliances/cfme/upstream
imgfac_storage=/home/nouser/storage
tests=/home/appliances/cfme/upstream/test/

find $upstream               -mtime +$days_to_keep_nightlies                              | xargs rm -rvf
find $tests                  -mtime +$days_to_keep_tests                                  | xargs rm -vf
find $imgfac_storage -type f -mtime +$days_to_keep_storage   -regex ".*\.\(body\|meta\)$" | xargs rm -vf

