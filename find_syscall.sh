#!/bin/bash

RES_INC="$( find /usr/include -name syscall.h | grep /bits/syscall.h )"
RES_INC_COUNT="$( echo "$RES_INC" | wc -l )"

FOUND="FALSE"

if [ "$RES_INC_COUNT" = "1" ]
then
	FOUND="TRUE"
fi

if [ "$FOUND" = "TRUE"  ]
then
	if [ "$1" = "-f" ]
	then
		echo "$RES_INC"

	elif ! [ -z "$1" ]
	then
		UNISTD64="$(./find_unistd.sh -d)/unistd_64.h"
		NRS="$(cat "$UNISTD64" | grep " $1"$ | grep "__NR_" )"

		NRS_COUNT="$( echo "$NRS" | wc -l )"

		if [ "$NRS_COUNT" = "1" ]
		then
			CUT_LEAD="${NRS##*#define }"
			NR="${CUT_LEAD% *}"

			RES_LINES="$(cat "$RES_INC" | grep "$NR"$ )"

			echo "$RES_LINES\n" |
			while read -r RES_LINE; do
				NO_DEFINE="${RES_LINE##*#define }"
				echo "${NO_DEFINE%% *}"
				break
			done
		else
			exit 1
		fi
	fi
fi
