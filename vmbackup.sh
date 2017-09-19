#!/bin/sh 
# File: vmbackup.sh
# Author: Andrea Giuliano
# Description: script per la shell di ESXi per la copia integrale di una macchina virtuale
# La VM viene spenta e tale rimane finche' il suo disco non e' copiato localmente.
# La copia effettiva viene effettuata subito dopo, con la VM gia' riavviata.

# 
# Alcune funzioni di comodo
#

# Formatta come hh:mm:ss un tempo in secondi

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
# Data e ora attuali in secondi dall'epoch
#

now()
{
  date +%s 
}

#
# Intervallo di tempi in secondi
#

lap()
{
  NEW=$(now)
  OLD=$1
  echo $((NEW - OLD)) 
}

#
# Log minimale, con id del processo e della VM in elaborazione
#

log() 
{ 
  echo "[$$] $1" 
} 

#
# Funzioni per l'output
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
# Clona localmente il disco virtuale
#
 
clone()
{
  awk -F=\  '/vmdk/ {gsub("\"","", $2) ; print $2}' $1/*.vmx \
  | while read disk ; do
    log "clonazione $1/$disk su $TEMP/$disk..." 
    #vmkfstools -i $1/$disk $TEMP/$disk > /dev/null
    vmkfstools -i $1/$disk $TEMP/$disk
  done
}

# 
# Esegue un comando dopo averlo visualizzato
#

run() 
{ 
  echo "[$$] $1" 
  eval "$1" 
} 

#
# Ricava l'id di una VM a partire dal nome (parola intera, case sensitive)
#

getId()
{
  vim-cmd vmsvc/getallvms | awk -v vm=$1 '$2 == vm {print $1}' 
}

# Inizio del programma principale

drow
log "vmbackup.sh avviato alle $(date +%T) del $(date +%F)"
drow

if [ -f vmbackup.run ]; then 
  pid=$(cat vmbackup.run) 
  log "E' gia' in corso il processo $pid, esco subito..." 
  exit 
fi 
 
log "Creo un lock file per il processo $$..." 
echo "$$" > vmbackup.run 
sleep 3 
 
SOURCE=/vmfs/volumes/datastore1 
TARGET=/vmfs/volumes/nas869 
TEMP=/vmfs/volumes/datastore1/temp
DAY="$(date +%u)"
 
if [ "$1" == "-n" ]; then 
  PO="$1" 
  log "Le VM non saranno avviate dopo la copia ($PO)" 
  shift 
fi 
echo 
srow 
astart=$(date +%s) 
for vm in "$@" ; do 
  #vmId=$(vim-cmd vmsvc/getallvms | awk -v vm=$vm '$2 == vm {print $1}') 
  vmId=$(getId "$vm")
  if [ "$vmId" != "" ]; then 
    pstart=$(date +%s) 
    log "$vm [$vmId] avvio backup alle $(date +%T) del $(date +%F)" 
    srow 
    #log "Backup di $vm [$vmId]..." 
    if vim-cmd vmsvc/power.getstate $vmId | grep -q "Powered on" ; then 
      log "$vm [$vmId] shutdown del guest..." 
      run "vim-cmd vmsvc/power.shutdown $vmId" 
      run "sleep 120" 
      run "vim-cmd vmsvc/power.getstate $vmId" 
    fi
    log "$vm [$vmId] clonazione dischi virtuali..." 
    run "rm -rf $TEMP"
    run "mkdir $TEMP"
    cstart=$(now)
    clone "$SOURCE/$vm"
    log "$vm [$vmId] copia temporanea file non-disco..." 
    run "cp $SOURCE/$vm/*.vmx $TEMP/"
    run "cp $SOURCE/$vm/*.vmxf $TEMP/"
    run "cp $SOURCE/$vm/*.nvram $TEMP/"
    run "cp $SOURCE/$vm/*.log $TEMP/"
    ctime=$(lap $cstart)
    log "$vm [$vmId] downtime $(ftime $ctime)..." 
    if [ "$PO" != "-n" ]; then 
      run "sleep 120" 
      log "$vm [$vmId] avvio del guest..." 
      run "vim-cmd vmsvc/power.on $vmId" 
    fi 
    run "vim-cmd vmsvc/power.getstate $vmId" 
    log "$vm [$vmId] inizio copia effettiva..." 
    run "rm -rf $TARGET/$vm-$DAY" 
    #run "cp -a $SOURCE/$vm $TARGET/$vm-$DAY" 
    run "cp -a $TEMP $TARGET/$vm-$DAY" 
    run "chmod -R a+r $TARGET/$vm-$DAY"
    log "$vm [$vmId] copia effettiva terminata..." 
    #log "$vm [$vmId] rimozione copia temporanea..." 
    #run "rm -rf $TEMP"
    pstop=$(date +%s) 
    ptime=$((pstop - pstart)) 
    log "$vm [$vmId] tempo parziale: $(ftime $ptime) ($ptime secondi)" 
    log "$vm [$vmId] finito alle $(date +%T) del $(date +%F)" 
    srow 
  fi 
done 
pstop=$(date +%s) 
ptime=$((pstop - astart)) 
log "Tempo totale: $(ftime $ptime) ($((ptime)) secondi)" 
drow 
log "Rimuovo il lock file per il processo $$" 
run "rm vmbackup.run"
