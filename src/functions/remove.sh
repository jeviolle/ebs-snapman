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


# print available options for remove command
function remove_help() {
cat <<EOF

Parameters for the 'remove' command

==== All options are EXCLUSIVE ====

  --all <owner id>            		remove all snapshots
  --snapshot-ids <s1,s2>      		snapshot(s) (comma separated) to remove
  --instance-ids <i1,i2>      		remove all snapshots for listed instance(s) (comma separated)
  --nametags <host1,host2>    		remove all snapshots for instances w/ this name tag (comma separated)

==== optional modifiers ====

  --force				forces snapshot removal when there are pending snapshots
  --exclude-volume-ids <vol1,vol2>      **exclude the listed volume(s) from processing (comma separated)
  --exclude-instance-ids <id1,id2>      **exclude these instance(s) from processing (comma separated)
  --exclude-nametags <host1,host2>      **exclude all instances w/ this name tag (comma separated)

  ** these do not work for 'remove --snapshot-ids <s1,s2>'

EOF
exit 1
}


# verify and process remove_options
function remove_options() {
  exclusive_count=0

  # option parser
  while [[ $# -ge 1 ]]
  do
    key="$1"
    case $key in
      --snapshot-ids)
        SNAPSHOTS="$2"
        count=`expr $count + 1`
        exclusive_count=`expr $exclusive_count + 1`
        shift
        ;;
      --all)
        ALL_SNAPSHOTS="$2"
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
        remove_help
        ;;
    esac
    shift
  done

  if [ $exclusive_count != 1 ]
  then
    exclusive_error
    remove_help
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
  if [ "x$SNAPSHOTS" != "x" ]
  then
    for snap in $SNAPSHOTS
    do
      remove_snapshot $snap
    done
  elif [ "x$ALL_SNAPSHOTS" != "x" ]
  then
    remove_all_snapshots $ALL_SNAPSHOTS
  elif [ "x$INSTANCE_IDS" != "x" ]
  then
    for id in $INSTANCE_IDS
    do
      remove_instance_snapshots $id
    done
  elif [ "x$NAMETAGS" != "x" ]
  then
    for name in $NAMETAGS
    do
      remove_snapshots_by_nametag $name
    done
  fi
}


# removes a snapshot
function remove_snapshot() {
  unset IFS
  [ "x$1" = "x" ] && echo "FAIL: No snapshot-id specified for remove_snapshot()...exiting" && exit 1
  snapshot=$1

  is_complete=$(${EC2_CMD} describe-snapshots --snapshot-ids $snapshot --filters Name=status,Values=completed | jq -r '.Snapshots[].SnapshotId')

  if [ "x$is_complete" = "x" -a "$FORCE" != 0 ]
  then
    echo "WARN: skipping snapshot removal for $snapshot , this snapshot is not complete."
    echo "      rerun with --force to continue regardless"
    return 1
  fi

  ${EC2_CMD} delete-snapshot --snapshot-id $snap

  echo "Deleted $snapshot"
}

# remove all snapshots (YIKES!)
function remove_all_snapshots() {
  unset IFS
  [ "x$1" = "x" ] && echo "FAIL: No owner-id specified for remove_all_snapshots()...exiting" && exit 1
  owner=$1
  snapshots=""

  echo "-----"
  echo "Removing all snapshots for owner-id: $owner"
  echo "-----"

  if [ "$FORCE" = 0 ]
  then
    snapshots=$(list_all_snapshots $owner | awk -F "\",\"" '{print $2}')
  else
    snapshots=$(list_all_snapshots $owner | grep '^"' | grep -v '100%' | awk -F "\",\"" '{print $2}')
  fi

  for snap in $snapshots
  do
    remove_snapshot $snap
  done
}

# removes all snapshots associated with this specified instance-id
function remove_instance_snapshots() {
  unset IFS
  [ "x$1" = "x" ] && echo "FAIL: No instance-id specified for remove_instance_snapshots()...exiting" && exit 1
  instance=$1
  snapshots=""

  echo "-----"
  echo "Removing snapshots for instance-id: $instance"
  echo "-----"

  if [ "$FORCE" = 0 ]
  then
    snapshots=$(list_instance_snapshots $instance | awk -F "\",\"" '{print $2}')
  else
    snapshots=$(list_instance_snapshots $instance | grep '^"' | grep -v '100%' | awk -F "\",\"" '{print $2}')
  fi

  for snap in $snapshots
  do
    remove_snapshot $snap
  done
}

# removes all snapshots associated with an instance-id name tag
function remove_snapshots_by_nametag() {
  unset IFS
  [ "x$1" = "x" ] && echo "FAIL: No instance Name tag specified for remove_snapshots_by_nametag()...exiting" && exit 1
  name=$1
  snapshots=""

  echo "-----"
  echo "Removing snapshots for instances that contain the Name tag: $name..."
  echo "-----"

  if [ "$FORCE" = 0 ]
  then
    snapshots=$(list_snapshots_by_nametag $name | awk -F "\",\"" '{print $2}')
  else
    snapshots=$(list_snapshots_by_nametag $name | grep '^"' | grep -v '100%' | awk -F "\",\"" '{print $2}')
  fi

  for snap in $snapshots
  do
    remove_snapshot $snap
  done
}
