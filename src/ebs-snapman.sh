#!/bin/bash
#
# ebs-snapman.sh - snapshot manager for AWS EBS Volumes
#
# Copyright (C) 2015, Rick Briganti
#
# This file is part of ebs-snapman
# 
# ebs-snapman is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# source everything
BASE=`dirname $0`
. ${BASE}/functions/main.sh


# if no command is specified print
# default usage
if [ $# -le 0 ]
then
  usage
  exit 1
fi

options=$@

# show help if it is specified
echo $options | grep -q '\-\-help'
[ $? = 0 ] && options_help && exit 1

# check for region and profile
REGION=`echo $options | perl -nle 'print $1 if /\-\-region\s+([\w|\-]+)/'`
PROFILE=`echo $options | perl -nle 'print $1 if /\-\-profile\s+([\w|\-]+)/'`
check_region_and_profile

# remove region and profile from $options
options=`echo $options | perl -p -e 's/\-\-region\s+([\w|\-]+)//' | sed 's/^[ \t]*//;s/[ \t]*$//'`
options=`echo $options | perl -p -e 's/\-\-profile\s+([\w|\-]+)//' | sed 's/^[ \t]*//;s/[ \t]*$//'`

# convert reminaing to an array and separate
IFS=' ' read -a remaining_args <<< "$options"
cmd="${remaining_args[0]}"
max="`expr ${#remaining_args[@]} - 1`"
count=1
suboption=""
while [ $count -le $max ]
do
  suboption="$suboption ${remaining_args[$count]}"
  count=`expr $count + 1`
done


# Variables
EC2_CMD="aws --region $REGION --profile $PROFILE ec2"
IAM_CMD="aws --region $REGION --profile $PROFILE iam"

# verify if a valid command has been specified
# and exit with available choices
case $cmd in
  create)
    create_options $suboption
    ;;
  remove)
    remove_options $suboption
    ;;
  list)
    list_options $suboption
    ;;
  *)
    usage
    echo "error: argument command: Invalid choice, valid choices are:"
    command_help
    exit 1
  ;;
esac





