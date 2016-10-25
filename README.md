# mysql-backup.sh
Backups all tables in all databases with ignore list into single files for each table.

This script checks, i´f a dump has changed, and only then updates the backup, so the 
backup folder can be archived easily with `rsnapshot`
