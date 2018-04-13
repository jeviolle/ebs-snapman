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

# globals
FORCE=1
declare -a EXCLUDED
EXCLUDED+=("DUMMY")

# general usage function
function usage() {
  prog=`basename $0`
  echo "Usage: $prog [options] <command> [parameters]"
}

# show available commands
function command_help() {
cat <<EOF

Available commands are:

  create
  list
  remove

EOF
}

function options_help() {
usage
cat <<EOF

  --help                        	this message

  --region <region>             	aws region  (see aws help for more info)
  --profile <profile>            	aws profile (see aws help for more info)

  Or you can fallback to the AWS CLI Environment for region, access_key_id, secret_access_key
  https://docs.aws.amazon.com/cli/latest/userguide/cli-environment.html

EOF
command_help
}

function options_error() {
  echo "error: argument options: Invalid choice, valid choices are:"
}

function exclusive_error() {
  echo "error: argument options: Multiple exclusive options were specified."
}

function check_awscli_options() {
  if [ "x$REGION" = "x" -o "x$PROFILE" = "x" ]
  then
    if [ "x$AWS_DEFAULT_REGION" != "x" -a "x$AWS_ACCESS_KEY_ID" != "x" -a "x$AWS_SECRET_ACCESS_KEY" != "x" ]
    then
      echo "info: falling back to using environment variables for AWS access.."
    else
      echo "FAIL: region/profile or aws environment not configured..."
      echo
      options_help
      exit 1
    fi
  fi
}

function exclude_volumes_for_instance() {
  unset IFS
  # either die or set the name variable
  [ "x$1" = "x" ] && echo "FAIL: No instance Name tag specified for exclude_volumes_for_instance()...exiting" && exit 1
  instance=$1

  vols=$(${EC2_CMD} describe-instances --instance-ids $instance | \
    jq -r '.Reservations[].Instances[].BlockDeviceMappings[] | .Ebs.VolumeId ')  

  # add each volume to the excluded global
  for v in $vols
  do
    EXCLUDED+=($v)
  done
}

function exclude_volumes_for_nametag() {
  unset IFS
  # either die or set the name variable
  [ "x$1" = "x" ] && echo "FAIL: No instance Name tag specified for exclude_volumes_for_nametag()...exiting" && exit 1
  name=$1

  # snap one instance's volumes at a time
  instances=$(${EC2_CMD} describe-instances --filters "Name=tag-key,Values=Name" "Name=tag-value,Values=$name" | \
    jq -r '.Reservations[].Instances[] | .InstanceId')

  for i in $instances
  do
    exclude_volumes_for_instance $i
  done
}

function warn_excluded() {
  unset IFS
  if [ "${#EXCLUDED[@]}" -gt 1 ]
  then    
    echo "-----"
    echo "INFO: Volume(s) are being excluded ..."
    echo "-----"
  fi      
}

. ${BASE}/functions/create.sh
. ${BASE}/functions/list.sh
. ${BASE}/functions/remove.sh
