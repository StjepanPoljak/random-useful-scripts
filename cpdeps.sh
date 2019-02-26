#!/bin/bash

if [ "$#" -ne 1 ] && [ "$#" -ne 2 ]
then
	echo "Need executable and optional path for argument."
	exit 1
fi

STACK=("$1")
PROCESSED=()

TARGET_DIR=""

if ! [ -z "$2" ]
then
	TARGET_DIR="${2%/}"
fi

while [ "${#STACK[@]}" -gt 0 ]
do
	CURR="${STACK[${#STACK[@]} - 1]}"
	
	unset "STACK[${#STACK[@]} - 1]"

	for each in $(ldd "$CURR" | grep .so)
	do
		if [ "${each:0:1}" = "/" ]
		then

			libdep="${each%%*=>}"
			
			FOUND=0
			for proc in "${PROCESSED[@]}"
			do
				if [ "$proc" = "$libdep" ]
				then
					FOUND=1
					break
				fi
			done

			if [ "$FOUND" -ne 1 ]
			then
				STACK+=("$libdep")
				PROCESSED+=("$libdep")
			fi
		fi
	done
done

for each in ${PROCESSED[@]}
do
	if ! [ -z "$TARGET_DIR" ]
	then
		cp --parents "$each" "$TARGET_DIR"
	else
		echo "$each"
	fi
done
