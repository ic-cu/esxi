#!/bin/sh

# local configuration options

# Note: modify at your own risk!  If you do/use anything in this
# script that is not part of a stable API (relying on files to be in
# specific places, specific tools, specific output, etc) there is a
# possibility you will end up with a broken system after patching or
# upgrading.  Changes are not supported unless under direction of
# VMware support.

cp /vmfs/volumes/datastore1/vmbackup.sh /
chmod u+x /vmbackup.sh
/bin/kill $(ps | grep crond | cut -d' ' -f1)
cat /vmfs/volumes/datastore1/crontab.local >> /var/spool/cron/crontabs/root
/bin/crond
    
exit 0
