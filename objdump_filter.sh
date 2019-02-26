#!/bin/bash

SECTIONS=()
FUNCTIONS=()
CURR_MODE=""
CONTENTS=`cat`

for ARG in "$@"
do
	CHECK_SINGLE="$(echo $ARG | cut -c 1-1)"
	CHECK_DOUBLE="$(echo $ARG | cut -c 1-2)"

	if [ "$CHECK_SINGLE" = "-" ] || [ "$CHECK_DOUBLE" = "--" ]
	then

		if [ "$ARG" = "--function" ] || [ "$ARG" = "-f" ]
		then
			CURR_MODE="function"
			continue
		elif [ "$ARG" = "--section" ] || [ "$ARG" = "-s" ]
		then
			CURR_MODE="section"
			continue
		else
			echo "(!) Invalid argument '$ARG'. Use --section (-s) or --function (-f) arguments to designate which parts of assembly dump to keer."
			exit 1
		fi
	fi

	if [ "$CURR_MODE" = "section" ]
	then
		SECTIONS+=("$ARG")	
	elif [ "$CURR_MODE" = "function" ]
	then
		FUNCTIONS+=("$ARG")
	elif [ "$CURR_MODE" = "" ]
	then
		echo "(!) No directives given. Use --section (-s) or --function (-f) arguments to designate which parts of assembly dump to keep."
		exit 2
	fi
done

SECTION_MARKER="Disassembly of section ."

DUMPING_SECTION="FALSE"
DUMPING_FUNCTION="FALSE"
DUMPING_HEADER="TRUE"

echo -ne "$CONTENTS\n" |
while IFS= read -r LINE
do

	if [ "$DUMPING_HEADER" = "TRUE" ]
	then
		case $LINE in
			"$SECTION_MARKER"*)
				DUMPING_HEADER="FALSE"
			;;
			*)
				echo "$LINE"
			;;
		esac

		continue
	fi

	if [ "$DUMPING_SECTION" = "FALSE" ] && [ "$DUMPING_FUNCTION" = "FALSE" ]
	then

		for FUN in "${FUNCTIONS[@]}"
		do
			case $LINE in
				*"<$FUN>:"*)
					DUMPING_FUNCTION="TRUE"
				;;
			esac
		done

	elif [ "$DUMPING_FUNCTION" = "TRUE" ]
	then

		case $LINE in
			*">:"*)
				DUMPING_FUNCTION="FALSE"
				continue
			;;
		esac
	fi

	case $LINE in

		"$SECTION_MARKER"*)
		
		if [ "$DUMPING_SECTION" = "TRUE" ] || [ "$DUMPING_FUNCTION" = "TRUE" ]
		then
			DUMPING_SECTION="FALSE"
			DUMPING_FUNCTION="FALSE"
			continue
		fi

		SEC_NAME_P1="${LINE#$SECTION_MARKER*}"
		SEC_NAME="${SEC_NAME_P1%%:*}"

		for SEC in "${SECTIONS[@]}"
		do
			if [ "$SEC_NAME" = "$SEC" ]
			then
				DUMPING_SECTION="TRUE"
			fi
		done
		;;
	esac

	if [ "$DUMPING_SECTION" = "TRUE" ] || [ "$DUMPING_FUNCTION" = "TRUE" ]
	then
		echo "$LINE"
	fi
done
