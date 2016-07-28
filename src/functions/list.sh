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


# print available options for list command
function list_help() {
cat <<EOF

Parameters for the 'list' command

==== EXCLUSIVE options ====

  --all <owner id>            		this will list all snapshots
  --volume-ids <vol1,vol2>    		list snapshots for these volumes(s) (comma separated)
  --instance-ids <i1,i2>      		list snapshots for defined instance(s) (comma separated)
  --nametags <host1,host2>    		list snapshots for instances w/ this name tag (comma separated)

==== optional modifiers ====

  --exclude-volume-ids <vol1,vol2>      exclude the listed volume(s) from processing (comma separated)
  --exclude-instance-ids <id1,id2>      exclude these instance(s) from processing (comma separated)
  --exclude-nametags <host1,host2>      exclude all instances w/ this name tag (comma separated)

EOF
exit 1
}

# verify and process list_options
function list_options() {
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
      --all)
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
      *)
        options_error
        list_help
        ;;
    esac
    shift
  done


  if [ $exclusive_count != 1 ]
  then
    exclusive_error
    list_help
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
      list_snapshots_by_volume $vol
    done
  elif [ "x$ALL_VOLUMES" != "x" ]
  then
    list_all_snapshots $ALL_VOLUMES
  elif [ "x$INSTANCE_IDS" != "x" ]
  then
    for id in $INSTANCE_IDS
    do
      list_instance_snapshots $id
    done
  elif [ "x$NAMETAGS" != "x" ]
  then
    for name in $NAMETAGS
    do
      list_snapshots_by_nametag $name
    done
  fi

}

# takes a volumeId and ownerId as arguments
function list_snapshots_by_volume() {
  unset IFS
  [ "x$1" = "x" ] && echo "FAIL: No volume-id specified for list_snapshots_by_volume()...exiting" && exit 1
  volume=$1

  echo "-----"
  echo "Listing all snapshots for volume-id: $volume"
  echo "-----"
  warn_excluded

  ${EC2_CMD} describe-snapshots --filters "Name=volume-id,Values=$volume" | \
    jq -r '.Snapshots[] | { VolumeId, SnapshotId, StartTime, Progress }' | \
    sed -e 's/{/-\t@/' | sed '/}/d' | awk '{print $2}' | tr '\n' " " | tr '@' '\n' | sed 's/ //g' | \
    egrep -v "(`echo ${EXCLUDED[@]} | sed 's/ /\|/g'`)" | sort -k3 -t,

  echo
}

# takes an owner-id as input and provides a list of snapshots in csv format
function list_all_snapshots() {
  unset IFS
  [ "x$1" = "x" ] && echo "FAIL: No owner-id specified for list_all_snapshots()...exiting" && exit 1
  owner=$1

  echo "-----"
  echo "Listing all snapshots for owner-id: $owner"
  echo "-----"
  warn_excluded

  # create csv tabular output from JSON with the fields in this order
  # VolumeId, SnapshotId, StartTime(timestamp), Progress(percent)
  ${EC2_CMD} describe-snapshots --owner-ids $owner | \
    jq -r '.Snapshots[] | { VolumeId, SnapshotId, StartTime, Progress }' | \
    sed -e 's/{/-\t@/' | sed '/}/d' | awk '{print $2}' | tr '\n' " " | tr '@' '\n' | sed 's/ //g' | \
    egrep -v "(`echo ${EXCLUDED[@]} | sed 's/ /\|/g'`)" | sort -k3 -t,

  echo
}

# list all snapshots for a particular instance
function list_instance_snapshots() {
  unset IFS
  [ "x$1" = "x" ] && echo "FAIL: No instance specified for list_instance_snapshots()...exiting" && exit 1
  instance=$1

  echo "-----"
  echo "Listing snapshots for instance-id: $instance..."
  echo "-----"
  warn_excluded

  # create csv tabular output from JSON with the fields in this order
  # VolumeId, SnapshotId, StartTime(timestamp), Progress(percent)
  ${EC2_CMD} describe-snapshots --filter "Name=tag-key,Values=src_instance" "Name=tag-value,Values=$instance" | \
    jq -r '.Snapshots[] | { VolumeId, SnapshotId, StartTime, Progress }' | \
    sed -e 's/{/-\t@/' | sed '/}/d' | awk '{print $2}' | tr '\n' " " | tr '@' '\n' | sed 's/ //g' | \
    egrep -v "(`echo ${EXCLUDED[@]} | sed 's/ /\|/g'`)" | sort -k3 -t,

  echo
}

# list all snapshots for all instances with the specified name tag
function list_snapshots_by_nametag() {
  unset IFS
  # either die or set the name variable
  [ "x$1" = "x" ] && echo "FAIL: No instance Name tag specified for list_snapshots_by_nametag()...exiting" && exit 1
  name=$1

  echo "-----"
  echo "Listing snapshots for instances that contain the Name tag: $name..."
  echo "-----"

  # list one instance's snapshots at a time
  instances=$(${EC2_CMD} describe-instances --filters "Name=tag-key,Values=Name" "Name=tag-value,Values=$name" | \
    jq -r '.Reservations[].Instances[] | .InstanceId')

  for i in $instances
  do
    list_instance_snapshots $i
  done

  echo
}
