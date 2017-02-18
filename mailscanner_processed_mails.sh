#!/bin/bash
# Retrieves the processed mails by MailScanner during the last timespan.
# 1st parameter: Password to access the MailScanner MySQL database.
# 2nd parameter: Defines the timespan in minutes.
# Wrong or invalid input defaults to 15 minutes.
if [ -z "$1" ]
then
  echo 4:0:Please provide the database password.
  exit
else
  DB_PWD=$1
fi

TIMESPAN=15
if [ ! -z "$2" ] && [ $2 -gt 0 ]
then TIMESPAN=$2
fi

PROCESSED_MAILS=$(mysql -u root -p$DB_PWD -N -B -e "select Count(*) from mailscanner.maillog where timestamp BETWEEN DATE_ADD(NOW(),INTERVAL - ${TIMESPAN} MINUTE) AND NOW();")

if [ $? -ne 0 ]
then
  echo 4:0:SQL Error. Is the password correct?
  exit
fi

if (($PROCESSED_MAILS < 1)) 
then
  echo 2:$PROCESSED_MAILS:No mails has beed processed by MailScanner during the last $TIMESPAN minutes.
else 
  echo 0:$PROCESSED_MAILS:$PROCESSED_MAILS mails processed during last $TIMESPAN minutes.
fi
