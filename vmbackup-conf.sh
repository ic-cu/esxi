# Some settings needed by vmbackup.sh

# The source directory contaning all VMs directories
SOURCE=/vmfs/volumes/datastore1

# The target directory where every specific VM directory will be copied.
# If you want it to be a remote directory, mount it as NFS.
#TARGET=/vmfs/volumes/nas869 
TARGET=

# The local temporary directory in which storing the relevant VM files
# before they are copied to the actual target, be it local or remote.
TEMP=/vmfs/volumes/datastore2/temp

