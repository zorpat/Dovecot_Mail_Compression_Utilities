#!/bin/bash
#
# Find the mails you want to compress in a single maildir.
#
#     Skip files that don't have ,S=<size> in the filename. 
#
# Compress the mails to tmp/
#
#     Update the compressed files' mtimes to be the same as they were in the original files (e.g. touch command) 
#
# Run maildirlock <path> <timeout>. It writes PID to stdout, save it.
#
#     <path> is path to the directory containing Maildir's dovecot-uidlist (the control directory, if it's separate)
# 
#     <timeout> specifies how long to wait for the lock before failing. 
#
# If maildirlock grabbed the lock successfully (exit code 0) you can continue.
# For each mail you compressed:
#
#     Verify that it still exists where you last saw it.
#     If it doesn't exist, delete the compressed file. Its flags may have been changed or it may have been expunged. This happens rarely, so just let the next run handle it.
#
#     If the file does exist, rename() (mv) the compressed file over the original file.
#
#         Dovecot can now read the file, but to avoid compressing it again on the next run, you'll probably want to rename it again to include e.g. a "Z" flag in the file name to mark that it was compressed (e.g. 1223212411.M907959P17184.host,S=3271:2,SZ). Remember that the Maildir specifications require that the flags are sorted by their ASCII value, although Dovecot itself doesn't care about that. 
#
# Unlock the maildir by sending a TERM signal to the maildirlock process (killing the PID it wrote to stdout). 
#
# Usage:
#
#	- ./dovecot-maildir-compress.sh /var/vmail/domain.com/
#
#
# !!!!!!!!!!!! A T T E N T I O N !!!!!!!!!!!! 
#
# This script zip's all messages that have not zipped before in secure mode (=> slower mode) (default: "secure=1")
# If you set "secure=0" then the script will zip all the messages older than 1 day, regardless they are zipped or not! (=> faster mode)
# Pay attention do this mode, since every message that was zipped before will be double-zipped and is not more usable!
#
# !!!!!!!!!!!! A T T E N T I O N !!!!!!!!!!!! 
# 

## Includes ##
. ./terminal-control.sh
## -------- ##

store=$1
secure=1
time="-mtime +1"
#compress=gzip
compress=bzip2

find "$store" -type d -name "cur" | while read maildir;
do
  echo -e "${Bold}${Yellow}Processing \"$maildir\"${Rst}"

  tmpdir=$(cd "$maildir/../tmp" &>/dev/null && pwd) || exit 1
  
  if [ "$secure" -eq 1  ];
  then
	  find=$(find "$maildir" -type f -name "*,S=*" ! -name "*,*:2,*,*Z*" -printf "%f\n")
		if [ -z "$find" ];
		then
		  continue
		fi

		echo "$find" | while read filename;
		do
			zipped=$(bzip2 -qt $maildir/$filename &>/dev/null)
			if [ $? -eq 0 ];
			then
				echo -e "${Bold}${Red}\"$filename\" was already zipped before!${Rst}"
				continue
			else
				echo -e "${Bold}${Green}->zipping \"$filename\"${Rst}"
			fi

			srcfile="$maildir/$filename"
			tmpfile="$tmpdir/$filename"

			$compress --best --stdout "$srcfile" > "$tmpfile" &&

			# Copy over some things
			chown --reference="$srcfile" "$tmpfile" &&
			chmod --reference="$srcfile" "$tmpfile" &&
			touch --reference="$srcfile" "$tmpfile"
		done
  else
	  find=$(find "$maildir" -type f -name "*,S=*" ${time} ! -name "*,*:2,*,*Z*" -printf "%f\n")
		if [ -z "$find" ];
		then
		  continue
		fi

		echo "$find" | while read filename;
		do
			echo -e "${Bold}${Green}->zipping \"$filename\"${Rst}"
			
			srcfile="$maildir/$filename"
			tmpfile="$tmpdir/$filename"

			$compress --best --stdout "$srcfile" > "$tmpfile" &&

			# Copy over some things
			chown --reference="$srcfile" "$tmpfile" &&
			chmod --reference="$srcfile" "$tmpfile" &&
			touch --reference="$srcfile" "$tmpfile"
		done  
  fi

	# Should really check dovecot-uidlist is in $maildir/..
	if lock=$(/usr/lib/dovecot/maildirlock "$maildir/.." 10);
	then
		# The directory is locked now
		echo -e "${Bold}${Green}Got Lock for \"$maildir\" with PID: $lock${Rst}"

		echo "$find" | while read filename;
		do
			flags=$(echo $filename | awk -F:2, '{print $2}')

			if echo $flags | grep ',';
			then
				newname=$filename"Z"
			else
				newname=$filename",Z"
			fi

			srcfile=$maildir/$filename
			tmpfile=$tmpdir/$filename
			dstfile=$maildir/$newname

			if [ -f "$srcfile" ] && [ -f "$tmpfile" ];
			then
				#echo "$srcfile -> $dstfile"

				mv "$tmpfile" "$srcfile" &&
				mv "$srcfile" "$dstfile"
			else
				rm -f "$tmpfile"
			fi
		done

		kill $lock
		
		echo -e "${Bold}${Green}Lock Released.${Rst}"
	else
		echo -e "${Bold}${Red}Failed to lock: $maildir${Rst}" >&2

		echo "$find" | while read filename;
		do
			rm -f "$tmpdir/$filename"
		done
	fi
done
