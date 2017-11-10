#!/bin/sh 
# File: vmbackup.sh
# Author: Andrea Giuliano
# Description: ESXi shell script to backup a VM remotely without
# downtime. It creates a snapshot, copies locally the VM relevant files,
# including the "frozen" disk files, then remove the snapshot and copies
# the local copy over the network to a configurable target directory.

# 
# Sources some functions and settings
#

cd ${0%/*}

. ./vmbackup-func.sh
. ./vmbackup-conf.sh

# Inizio del programma principale

drow
log "vmbackup.sh started at $(date +%T) on $(date +%F)"
drow

if [ -f vmbackup.run ]; then 
  pid=$(cat vmbackup.run) 
  log "The process $pid is already running, I stop immediately..." 
  exit 
fi 
 
log "Creating a lock file for process $$..." 
echo "$$" > vmbackup.run 
sleep 3 
 

# The day of week as a number, to mark different copies.
DAY="$(date +%u)"
 
echo 
srow 
astart=$(date +%s) 

# Loops on VM names given as parameters. These are not the directories
# in which the VM files are, though they may be the same.

for vm in "$@" ; do 
  vmId=$(getId "$vm")
  vmDir=$(getDir "$vm")
  if [ "$vmId" != "" ]; then 
    pstart=$(date +%s) 
    log "$vm [$vmId] backup started at $(date +%T) on $(date +%F)" 
    srow 
    log "Backing up $vm [$vmId]..." 
    run "rm -rf $TEMP"
    run "mkdir $TEMP"
    cstart=$(now)

# We need two lists: one of VMDK files and one of the other essential
# VM files. Logs and swap files are usually not needed. The files of the
# two lists will be copied at different time: the latter before taking
# the snapshot, the earlier after.

    CP1=$(ls -1 $vmDir/*.vmx $vmDir/*.vmxf $vmDir/*.nvram $vmDir/*.vmsd 2> /dev/null)
    CP2=$(ls -1 $vmDir/*.vmdk)

# Non VMDK files are copied before the snapshot, which alters 
# temporarily some of them.

    log "$vm [$vmId] non-disk files local copy..." 
    for FF in $CP1 ; do run "cp -a $FF $TEMP/" ; done

# Now we take a snapshot of the powered off VM, so the copy can be 
# started without warnings about bad shutdown. The snapshot will last
# just the time needed for copying locally all the big VMDK files.

		dstart=$(now)
		log "$vm [$vmId] shutting down..."
		shutdown $vmId
		waitUntilOff $vmId
	  log "$vm [$vmId] creating a snapshot..." 
    vim-cmd vmsvc/snapshot.create $vmId snapshot-$vmId
		log "$vm [$vmId] powering on..."
		powerOn $vmId
		waitUntilOn $vmId
    dtime=$(lap $dstart)
    log "$vm [$vmId] has been down for $(ftime $ctime)..." 

# Local copy of the VMDK files. We just wait a few seconds.

		sleep 10
    log "$vm [$vmId] disk files local copy..." 
    for FF in $CP2 ; do run "cp -a $FF $TEMP/" ; done
    ctime=$(lap $cstart)
    log "$vm [$vmId] local copy took $(ftime $ctime)..." 
    
# We don't need the snapshot any longer, so we delete it. We assume
# no other snapshot are needed. If it's not the case, the command below
# should be modified.

	  log "$vm [$vmId] removing all snapshots..." 
  	vim-cmd vmsvc/snapshot.removeall $vmId
  	
# The remote copy can start immediately: the files to be copied are all
# frozen and are not affected by the snapshot removal process. The copy
# is only made if $TARGET is not empty

		if [ $TARGET ]; then 
	    log "$vm [$vmId] starting remote copy..."
	    run "rm -rf $TARGET/$vm-$DAY" 
  	  run "cp -a $TEMP $TARGET/$vm-$DAY" 
  	  run "chmod -R a+r $TARGET/$vm-$DAY"
  	  log "$vm [$vmId] remote copy completed..." 
  	  pstop=$(date +%s) 
  	  ptime=$((pstop - pstart)) 
  	  log "$vm [$vmId] lap time: $(ftime $ptime) ($ptime seconds)" 
  	  log "$vm [$vmId] finished at $(date +%T) on $(date +%F)" 
  	  srow
  	 else
  	 	log "$vm [$vmId] empty target, skipping remote copy..."
  	 fi 
  fi 
done 
pstop=$(date +%s) 
ptime=$((pstop - astart)) 
log "Total time: $(ftime $ptime) ($((ptime)) seconds)" 
drow 
log "Removing lock file for process $$" 
run "rm vmbackup.run"
