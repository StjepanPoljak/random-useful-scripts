#!/bin/bash

RES_INC="$( find /usr/include -name unistd.h | grep /asm/unistd.h )"
RES_INC_COUNT="$( echo "$RES_INC" | wc -l )"

FOUND="FALSE"

if [ "$RES_INC_COUNT" = "1" ]
then
	FOUND="TRUE"
fi

if [ "$1" = "-a" ]
then
	if [ "$FOUND" = "TRUE"  ]
	then
		UNISTD_PATH="${RES_INC%/*}"
		FILES="$(ls $UNISTD_PATH | grep unistd)"
		for FILE in $FILES
		do
			echo "$UNISTD_PATH/$FILE"
		done
	fi

elif ! [ -z "$1" ]
then
	echo "(!) Unknown argument. Use -a."

elif [ "$FOUND" = "TRUE"  ]
then
	echo "$RES_INC"
fi
