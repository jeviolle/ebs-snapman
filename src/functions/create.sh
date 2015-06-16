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


# print available options for create command
function create_help() {
cat <<EOF

Parameters for the 'create' command

==== All options are EXCLUSIVE ====

  --volume-ids <vol1,vol2>        	volumes(s) (comma separated) to snap
  --all-used-volumes <owner id>   	this will snap all volumes in use by ec2 instances
  --all-volumes <owner id>        	this will snap both used/unused volumes
  --instance-ids <i1,i2>          	instance(s) (comma separated) to snap
  --nametags <host1,host2>        	snap instances w/ this name tag (comma separated)

==== optional modifiers ====

  --force				forces snapshot creation when there are pending snapshots
  --exclude-volume-ids <vol1,vol2>      exclude the listed volume(s) from processing (comma separated)
  --exclude-instance-ids <id1,id2>      exclude these instance(s) from processing (comma separated)
  --exclude-nametags <host1,host2>      exclude all instances w/ this name tag (comma separated)

EOF
exit 1
}


# verify and process create options
function create_options() {
  exclusive_count=0

  # option parser
  while [[ $# > 1 ]]
  do
    key="$1"
    case $key in
      --volume-ids)
        VOLUMES="$2"
        count=`expr $count + 1`
        exclusive_count=`expr $exclusive_count + 1`
        shift
        ;;
      --all-used-volumes)
        ALL_USED_VOLUMES="$2"
        count=`expr $count + 1`
        exclusive_count=`expr $exclusive_count + 1`
        ;;
      --all-volumes)
        ALL_VOLUMES="$2"
        count=`expr $count + 1`
        exclusive_count=`expr $exclusive_count + 1`
        ;;
      --instance-ids)
        INSTANCE_IDS="$2"
        count=`expr $count + 1`
        exclusive_count=`expr $exclusive_count + 1`
        shift
        ;;
      --nametags)
        NAMETAGS="$2"
        count=`expr $count + 1`
        exclusive_count=`expr $exclusive_count + 1`
        shift
        ;;
      --exclude-volume-ids)
        EXCLUDED_VOLUMES="$2"
        shift
        ;;
      --exclude-instance-ids)
        EXCLUDED_INSTANCE_IDS="$2"
        shift
        ;;
      --exclude-nametags)
        EXCLUDED_NAMETAGS="$2"
        shift
        ;;
      --force)
	FORCE=0
	shift
	;;
      *)
        options_error
        create_help
        ;;
    esac
    shift
  done

  check_region_and_profile "create"

  if [ $exclusive_count != 1 ]
  then
    exclusive_error
    create_help
  fi

  # change field separator
  IFS=','

  # process 'excluded' 
  if [ "x$EXCLUDED_VOLUMES" != "x" ]
  then
    for vol in $EXCLUDED_VOLUMES
    do
      EXCLUDED+=($vol)
    done
  elif [ "x$EXCLUDED_INSTANCE_IDS" != "x" ]
  then
    for instance in $EXCLUDED_INSTANCE_IDS
    do
      exclude_volumes_for_instance $instance
    done
  elif [ "x$EXCLUDED_NAMETAGS" != "x" ]
  then
    for nametag in $EXCLUDED_NAMETAGS
    do
      exclude_volumes_for_nametag $nametag
    done
  fi

  # process the specified option
  if [ "x$VOLUMES" != "x" ]
  then
    for vol in $VOLUMES
    do
      snap_volume $vol
    done
  elif [ "x$ALL_USED_VOLUMES" != "x" ]
  then
    snap_used_volumes $ALL_USED_VOLUMES
  elif [ "x$ALL_VOLUMES" != "x" ]
  then
    snap_all_volumes $ALL_VOLUMES
  elif [ "x$INSTANCE_IDS" != "x" ]
  then
    for id in $INSTANCE_IDS
    do
      snap_instance_volumes $id
    done
  elif [ "x$NAMETAGS" != "x" ]
  then
    for name in $NAMETAGS
    do
      snap_volumes_by_nametag $name
    done
  fi
}

# generic function to snap and tag a single volume
function snap_volume() {
  unset IFS
  # either die or set the volume variable
  [ "x$1" = "x" ] && echo "FAIL: No volume specified for snap_volume()...exiting" && exit 1
  vol=$1

  pending_snapshots=$(list_snapshots_by_volume $vol | grep '^"' | grep -v '100%' | wc -l)
  if [ "$pending_snapshots" -gt 0 -a "$FORCE" = 1 ]
  then
    echo "WARN: skipping create snapshot for $vol ,there are pending volume snapshots."
    echo "      rerun with --force to continue regardless"
    return 1
  fi

  echo "-----"
  # create the snapshot
  snapshot=$(${EC2_CMD} create-snapshot --volume-id $vol | jq -r '.|.SnapshotId')

  # get value for tags
  instance=$(${EC2_CMD} describe-volumes --volume $vol | jq -r '.Volumes[] | .Attachments[] | .InstanceId')
  instance_type=$(${EC2_CMD} describe-instances --instance-ids $instance | \
    jq -r '.Reservations[] | .Instances[] | .InstanceType' )
  instance_name=$(${EC2_CMD} describe-instances --instance-ids $instance | \
    jq -r '.Reservations[].Instances[].Tags[] | if .Key == "Name" then .Value else empty end')
  snap_user=$(${IAM_CMD} get-user | jq -r '.User.UserName')
  device=$(${EC2_CMD} describe-volumes --volume $vol | jq -r '.Volumes[] | .Attachments[] | .Device')


  # create tags
  # there is a default StartTime that is created by the snapshot process
  ${EC2_CMD} create-tags --resources $snapshot --tags Key=ebs_snapman,Value=1 > /dev/null
  ${EC2_CMD} create-tags --resources $snapshot --tags Key=src_instance,Value=$instance > /dev/null
  ${EC2_CMD} create-tags --resources $snapshot --tags Key=device,Value=$device > /dev/null
  ${EC2_CMD} create-tags --resources $snapshot --tags Key=src_instance_type,Value=$instance_type > /dev/null
  ${EC2_CMD} create-tags --resources $snapshot --tags Key=snap_user,Value=$snap_user > /dev/null
  [ "x$instance_name" != "x" ] && \
    ${EC2_CMD} create-tags --resources $snapshot --tags Key=src_instance_name,Value=$instance_name > /dev/null

  # some ouput
  echo "Created snapshot $snapshot for volume $vol"
}

# snaps all "in use" volumes
function snap_used_volumes() {
  unset IFS
  [ "x$1" = "x" ] && echo "FAIL: No owner-id specified for snap_used_volumes()...exiting" && exit 1
  owner=$1
  excluded_regex=`echo ${EXCLUDED[@]} | tr ' ' '|'`

  echo "-----"
  echo "Taking snapshots for all used volumes in ${REGION}:${PROFILE}..."
  echo "-----"
  warn_excluded

  vols=$(${EC2_CMD} describe-volumes --owner-ids $owner --filters "Name=status,Values=in-use" | jq -r '.Volumes[] | .VolumeId')

  for vol in `echo $vols | perl -p -e "s/($excluded_regex)//g" | perl -p -e 's/\s+/ /'`
  do
    snap_volume $vol
  done
}

# snaps all volumes regardless of status
function snap_all_volumes() {
  unset IFS
  [ "x$1" = "x" ] && echo "FAIL: No owner-id specified for snap_all_volumes()...exiting" && exit 1
  owner=$1
  excluded_regex=`echo ${EXCLUDED[@]} | tr ' ' '|'`

  echo "-----"
  echo "Taking snapshots for all volumes in ${REGION}:${PROFILE}..."
  echo "-----"
  warn_excluded

  vols=$(${EC2_CMD} describe-volumes --owner-ids $owner | jq -r '.Volumes[] | .VolumeId')

  for vol in `echo $vols | perl -p -e "s/($excluded_regex)//g" | perl -p -e 's/\s+/ /'`
  do
    snap_volume $vol
  done
}

# snap a particular instances volumes
function snap_instance_volumes() {
  unset IFS
  # either die or set the name variable
  [ "x$1" = "x" ] && echo "FAIL: No instance Name tag specified for snap_instance_volumes()...exiting" && exit 1
  instance=$1
  excluded_regex=`echo ${EXCLUDED[@]} | tr ' ' '|'`

  pending_snapshots=$(list_instance_snapshots $instance | grep '^"' | grep -v '100%' | wc -l)
  if [ "$pending_snapshots" -gt 0 -a "$FORCE" = 1 ]
  then
    echo "WARN: skipping create snapshot for $instance ,there are pending instance snapshots."
    echo "      rerun with --force to continue regardless"
    return 1
  fi

  echo "-----"
  echo "Taking snapshots for instance-id: $instance..."
  echo "-----"
  warn_excluded

  vols=$(${EC2_CMD} describe-instances --instance-ids $instance | \
    jq -r '.Reservations[].Instances[].BlockDeviceMappings[] | .Ebs.VolumeId ')

  for vol in `echo $vols | perl -p -e "s/($excluded_regex)//g" | perl -p -e 's/\s+/ /'`
  do
    snap_volume $vol
  done
}

# takes instance Name tag argument and snaps all volumes for that instance
# if there are more then one with the same name snap those as well
# good for groups of instances with the same name tag
function snap_volumes_by_nametag() {
  unset IFS
  # either die or set the name variable
  [ "x$1" = "x" ] && echo "FAIL: No instance Name tag specified for snap_instance_volumes()...exiting" && exit 1
  name=$1

  echo "-----"
  echo "Taking snapshots for volumes belong to the Name tag: $name..."
  echo "-----"

  # snap one instance's volumes at a time
  instances=$(${EC2_CMD} describe-instances --filters "Name=tag-key,Values=Name" "Name=tag-value,Values=$name" | \
    jq -r '.Reservations[].Instances[] | .InstanceId')

  for i in $instances
  do
    snap_instance_volumes $i
  done
}
