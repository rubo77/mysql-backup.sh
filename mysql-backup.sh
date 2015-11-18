#!/bin/bash
# mysql-backup.sh

if [ -z "$1" ] ; then
  echo
  echo "ERROR: root password Parameter missing."
  exit
fi
DB_host=localhost
MYSQL_USER=root
MYSQL_PASS=$1
MYSQL_CONN="-u${MYSQL_USER} -p${MYSQL_PASS}"
#MYSQL_CONN=""
TMP=mysql-backup.sql

BACKUP_DIR=/backup/mysql/
#BACKUP_DIR=/var/backups/mysql/

mkdir $BACKUP_DIR -p

# neue backups erstellen
MYSQLPATH=/var/lib/mysql/

IGNORE="database1.table1, database1.table2, database2.table1,"

# strpos $1 $2 [$3]
# strpos haystack needle [optional offset of an input string]
strpos()
{
    local str=${1}
    local offset=${3}
    if [ -n "${offset}" ]; then
        str=`substr "${str}" ${offset}`
    else
        offset=0
    fi
    str=${str/${2}*/}
    if [ "${#str}" -eq "${#1}" ]; then
        return 0
    fi
    echo $((${#str}+${offset}))
}

echo "started "$(date)>>/var/log/mysql/backup.log 

cd $MYSQLPATH
for i in */; do
    if [ $i != 'performance_schema/' ] ; then 
	DB=`basename "$i"` 
        #echo "backup $DB->$BACKUP_DIR$DB.sql.lzo"
        #mysqlcheck "$DB" $MYSQL_CONN --silent --auto-repair --optimize >/tmp/tmp_grep_mysql-backup
        mysqlcheck "$DB" $MYSQL_CONN --silent --auto-repair >/tmp/tmp_grep_mysql-backup
        grep -E -B1 "note|warning|support|auto_increment|required|locks" /tmp/tmp_grep_mysql-backup>/tmp/tmp_grep_mysql-backup_not
        grep -v "$(cat /tmp/tmp_grep_mysql-backup_not)" /tmp/tmp_grep_mysql-backup
        
	# lzop is much faster:http://pokecraft.first-world.info/wiki/Quick_Benchmark:_Gzip_vs_Bzip2_vs_LZMA_vs_XZ_vs_LZ4_vs_LZO
       	tbl_count=0
	for t in $(mysql -NBA -h $DB_host $MYSQL_CONN -D $DB -e 'show tables') 
	do
	  found=$(strpos "$IGNORE" "$DB"."$t,")
	  if [ "$found" == "" ] ; then 
	    #echo "DUMPING TABLE: $DB.$t"
	    #mysqldump -h $DB_host $MYSQL_CONN $DB $t --events --skip-lock-tables | grep -v '^-- Dump completed on .*$' | lzop -3 -f -o $BACKUP_DIR/$DB.$t.sql.lzo
	    #set -x        
	    mysqldump -h $DB_host $MYSQL_CONN $DB $t --events --skip-lock-tables | grep -v '^-- Dump completed on .*$' > /tmp/$TMP
            if [ ! -f $BACKUP_DIR$DB.$t.sql.gz ] || [ "$(zdiff -q /tmp/$TMP $BACKUP_DIR$DB.$t.sql.gz)" != "" ]; then
              echo $DB.$t changed
              cd /tmp
	      gzip -c $TMP > $BACKUP_DIR$DB.$t.sql.gz
            fi
	    tbl_count=$(( tbl_count + 1 ))
	  fi
	done
	echo "$tbl_count tables dumped from database '$DB' into dir=$BACKUP_DIR"
	#exit
    fi
done

# backups aelter als 1 tag löschen
find $BACKUP_DIR -atime +1 -exec rm {} \;

# grosse dateien finden mit
ls -lah /var/backups/rsnapshot/*/localhost$BACKUP_DIR*|grep G

# backups groesser als 1GB löschen
find $BACKUP_DIR -size +1000M -exec rm {} \;


echo "finished "$(date)>>/var/log/mysql/backup.log
