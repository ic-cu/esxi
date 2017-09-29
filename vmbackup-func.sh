# Some functions needed to run vmbackup.sh

# Format a time in seconds as hh:mm:ss

ftime() 
{ 
  ptime=$1 
  ph=$((ptime/3600)) 
  ptime=$((ptime%3600)) 
  pm=$((ptime/60)) 
  ps=$((ptime%60)) 
  printf "%02d:%02d:%02d" $ph $pm $ps 
} 

#
# The number of seconds since the Epoch
#

now()
{
  date +%s 
}

#
# A time interval expressed in seconds.
#

lap()
{
  NEW=$(now)
  OLD=$1
  echo $((NEW - OLD)) 
}

#
# A very minimalistic logging system, showing the input message always
# preceeded by the process id
#

log() 
{ 
  echo "[$$] $1" 
} 

#
# Some text output functions
#
 
drow() 
{ 
  log "===================================================" 
} 
 
srow() 
{ 
  log "---------------------------------------------------" 
} 

# 
# Run a command logging it
#

run() 
{ 
  echo "[$$] $1" 
  eval "$1" 
} 

#
# Returns a VM id given its name (inventory name, whole word, case sensitive)
#

getId()
{
  vim-cmd vmsvc/getallvms | awk -v vm=$1 '$2 == vm {print $1}' 
}

#
# Same as above, but returns the directory containing the file of a
# given VM
#

getDir()
{
  vim-cmd vmsvc/getallvms | awk -v vm=$1 '$2 == vm {print $4}' | grep -v Guest |cut -d\/ -f1
}


#
# Waits until a VM goes on/off. No check is made whether the VM exists
# 

waitUntilOn()
{
	while vim-cmd vmsvc/power.getstate $1 | grep -q "Powered off" ; do \
		sleep 10
	done
}

waitUntilOff()
{
	while vim-cmd vmsvc/power.getstate $1 | grep -q "Powered on" ; do \
		sleep 10
	done
}

#
# Powers on/off a VM (no checks for its existence)
#

powerOn()
{
	vim-cmd vmsvc/power.on $1
}

shutdown()
{
	vim-cmd vmsvc/power.shutdown $1
}
