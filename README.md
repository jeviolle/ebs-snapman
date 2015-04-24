# Summary

`ebs-snapman` is a utility to assist with the creation and management of AWS EC2 EBS snapshots. This is meant to be used manually,cron, or integrated into other backup processes.

# Dependencies

***These can be verified prior to installation.***
***See the "Installation" section below***

####Operating System

*I assume this could be made to work under cygwin*

```
linux or Mac OSX (bash,grep,sed,awk,expr,perl,python)
```

####Extra packages

```
jq (http://stedolan.github.io/jq/ or check your package manager)
awscli (pip install awscli)
```

# AWS Permissions

The following permissions are required:

####EC2


```
create-snapshot
create-tags
delete-snapshot
describe-snapshots
describe-instances
describe-volumes

```

####IAM

```
get-user
```

# Installation

By default this will be installed to `/opt`. If you would like it to go somewhere else just edit **PREFIX** in the **Makefile**.

```
help:

  *default PREFIX is /opt

  make testdeps           checks that all deps are met
  make install            installs ebs-snapman to PREFIX
  make uninstall          removes ebs-snapman from PREFIX

```

# Features and Usage

No need to pass credentials for authentication. Since this tool uses the AWS CLI you only need to specify the region and profile name as defined in `~/.aws/credentials`.

```
Usage: ebs-snapman.sh [options] <command> [parameters]

  --help                          this message
  --region <region>               aws region  (see aws help for more info)
  --profile <profile>             aws profile (see aws help for more info)


Available commands are:

  create
  list
  remove

```

### Creating snapshots

You can create snapshots by specifying a list of volumes, instances, or name-tags. You can also choose to snap all volumes for your AWS account or all USED volumes to avoid snapping volumes that were never cleaned up.

```
--volume-ids <vol1,vol2>        volumes(s) (comma separated) to snap
--all-used-volumes <owner id>   this will snap all volumes in use by ec2 instances
--all-volumes <owner id>        this will snap both used/unused volumes
--instance-ids <i1,i2>          instance(s) (comma separated) to snap
--nametags <host1,host2>        snap instances w/ this name tag (comma separated)
```

During the snapshot creation process, each snapshot is generated with several additional tags to assist you with any recovery that may be needed.

```
ebs_snapman=1       # to denote that this was created by this program
src_instance        # shows which instance this snapshot belongs to
device              # associates this snapshot with a device (eg: /dev/sdg)
src_instance_type   # the instance type .. in case you really need to know
snap_user           # the IAM user that created the snapshot
src_instance_name   # the instance name-tag
```


### Listing snapshots

You can list snapshots by specifying a list of volumes, instances, or name-tags. You can also choose to list all snapshots for your AWS account. Listing snapshots will provide a simple comma separated output with the following information:

```
VolumeId, SnapshotId, StartTime(timestamp), Progress(percent)
```

Below is the options as presented at the terminal:

```
--all <owner id>            this will list all snapshots
--volume-ids <vol1,vol2>    list snapshots for these volumes(s) (comma separated)
--instance-ids <i1,i2>      list snapshots for defined instance(s) (comma separated)
--nametags <host1,host2>    list snapshots for instances w/ this name tag (comma separated)
```

The idea is to provide you and I with enough information to create our own snapshot rotation by parsing this information and leverage the `remove` functionality of this program.

### Removing snapshots

You can remove snapshots by specifying a list of snapshots, instances, or name-tags. You can all choose to remove all snapshots for your AWS account.

```
--all <owner id>            remove all snapshots
--snapshot-ids <s1,s2>      snapshot(s) (comma separated) to remove
--instance-ids <i1,i2>      remove all snapshots for listed instance(s) (comma separated)
--nametags <host1,host2>    remove all snapshots for instances w/ this name tag (comma separated)
```
