#!/bin/bash

SECTIONS=()
FUNCTIONS=()
SYSCALLS=()
CURR_MODE=""
CONTENTS=`cat`
FUNC_FILTER_MODE=""
SECT_FILTER_MODE=""
SYSC_FILTER_MODE=""

SECTION_LCOM="section"
SECTION_SCOM="s"
FUNCTION_LCOM="function"
FUNCTION_SCOM="f"
SYSCALL_LCOM="syscall"
SYSCALL_SCOM="S"

PREV_EAX=""
PREV_RAX=""

MARKER_SET="\033[1m"
MARKER_RESET="\033[0m"

for ARG in "$@"
do
	CHECK_SINGLE="$(echo $ARG | cut -c 1-1)"
	CHECK_DOUBLE="$(echo $ARG | cut -c 1-2)"

	if [ "$CHECK_SINGLE" = "-" ] || [ "$CHECK_DOUBLE" = "--" ]
	then

		if [ "$ARG" = "--$FUNCTION_LCOM" ] || [ "$ARG" = "-$FUNCTION_SCOM" ]
		then
			CURR_MODE="function"
			continue
		elif [ "$ARG" = "--$SECTION_LCOM" ] || [ "$ARG" = "-$SECTION_SCOM" ]
		then
			CURR_MODE="section"
			continue
		elif [ "$ARG" = "--$SYSCALL_LCOM" ] || [ "$ARG" = "-$SYSCALL_SCOM" ]
		then
			CURR_MODE="syscall"
			continue
		else
			echo "(!) Invalid argument '$ARG'. Use --section (-s), --function (-f) and --syscall (-S) arguments to designate which parts of assembly dump to keep. Use '*' in front of section or function names to designate emphasized output."
			exit 1
		fi
	fi

	if [ "$CURR_MODE" = "section" ]
	then
		SECTIONS+=("$ARG")

	elif [ "$CURR_MODE" = "function" ]
	then
		FUNCTIONS+=("$ARG")

	elif [ "$CURR_MODE" = "syscall" ]
	then
		SYSCALLS+=("$ARG")

	elif [ "$CURR_MODE" = "" ]
	then
		echo "(!) No directives given. Use --section (-s), --function (-f) and --syscall (-S) arguments to designate which parts of assembly dump to keep. Use '*' in front of section or function names to designate emphasized output."
		exit 2
	fi
done

SECTION_MARKER="Disassembly of section ."

DUMPING_SECTION="FALSE"
DUMPING_FUNCTION="FALSE"
DUMPING_HEADER="TRUE"
DUMPING_SYSCALL="FALSE"

CURR_SECT=""
CURR_FUNC=""
CURR_SYSC=""

CURR_LINE_NUMBER=-1

ECHO_LINE_BYPASS="FALSE"

echo -ne "$CONTENTS\n" |
while IFS= read -r LINE
do
	((CURR_LINE_NUMBER++))

	if [ "$DUMPING_HEADER" = "TRUE" ]
	then
		case $LINE in

			"$SECTION_MARKER"*)
				DUMPING_HEADER="FALSE"
			;;

			*)
				echo "$LINE"
				continue
			;;
		esac
	fi

	if [ "$DUMPING_FUNCTION" = "FALSE" ]
	then
		for FUN in "${FUNCTIONS[@]}"
		do
			FUN_F="$FUN"

			if [ "$(echo $FUN | cut -c 1-1)" = "*" ]
			then
				FUN_F="${FUN##*\*}"

			elif [ "$(echo $FUN | cut -c 1-1)" = "%" ]
			then
				FUN_F="${FUN##*%}"
			fi

			case $LINE in

				*"<$FUN_F>:"*)

					DUMPING_FUNCTION="TRUE"

					if [ "$(echo $FUN | cut -c 1-1)" = "*" ]
					then
						FUNC_FILTER_MODE="EMPHASIZE"
						CURR_FUNC="${FUN##*\*}"
						echo -ne "$MARKER_SET"

					elif [ "$(echo $FUN | cut -c 1-1)" = "%" ]
					then
						FUNC_FILTER_MODE="ASCII"
						echo -ne "$LINE .ascii "
						CURR_FUNC="${FUN##*%}"
					else
						FUNC_FILTER_MODE="FILTER"
						CURR_FUNC="$FUN"
					fi
				;;
			esac
		done

	else
		case $LINE in

			*">:"*)

				DUMPING_FUNCTION="FALSE"
				if [ "$FUNC_FILTER_MODE" = "EMPHASIZE" ] && (! [ "$SECT_FILTER_MODE" = "EMPHASIZE" ] || [ "$DUMPING_SECTION" = "FALSE" ])
				then
					echo -ne "$MARKER_RESET"

				elif [ "$FUNC_FILTER_MODE" = "ASCII" ]
				then
					echo -ne "\n"
				fi
				
				CURR_FUNC=""

				continue
			;;
		esac
	fi

	case $LINE in

		"$SECTION_MARKER"*)

			if [ "$DUMPING_SECTION" = "TRUE" ] || [ "$DUMPING_FUNCTION" = "TRUE" ]
			then
				if [ "$DUMPING_FUNCTION" = "TRUE" ] && [ "$FUNC_FILTER_MODE" = "EMPHASIZE" ] && (! [ "$SECT_FILTER_MODE" = "EMPHASIZE" ] || [ "$DUMPING_SECTION" = "FALSE" ])
				then
					echo -ne "$MARKER_RESET"

				elif [ "$DUMPING_FUNCTION" = "TRUE" ] && [ "$FUNC_FILTER_MODE" = "ASCII"  ]
				then
					echo -ne "\n"
				fi

				if [ "$DUMPING_SECTION" = "TRUE" ] && [ "$SECT_FILTER_MODE" = "EMPHASIZE" ]
				then
					echo -ne "$MARKER_RESET"
				fi

				DUMPING_SECTION="FALSE"
				DUMPING_FUNCTION="FALSE"
				DUMPING_SYSCALL="FALSE"
				CURR_FUNC=""
				CURR_SECT=""
				CURR_SYSC=""
			fi

			SEC_NAME_P1="${LINE#$SECTION_MARKER*}"
			SEC_NAME="${SEC_NAME_P1%%:*}"

			for SEC in "${SECTIONS[@]}"
			do
				SEC_F="$SEC"

				if [ "$(echo $SEC_F | cut -c 1-1)" = "*" ]
				then
					SEC_F="${SEC##*\*}"
					SECT_FILTER_MODE="EMPHASIZE"
				else
					SEC_F="$SEC"
					SECT_FILTER_MODE="FILTER"
				fi

				if [ "$SEC_F" = "$SEC_NAME" ]
				then
					if [ "$SECT_FILTER_MODE" = "EMPHASIZE" ]
					then
						echo -ne "$MARKER_SET"
					fi

					DUMPING_SECTION="TRUE"
					CURR_SEC="$SEC_F"
				fi
			done
		;;
	esac

	if [ "$DUMPING_SECTION" = "TRUE" ] || [ "$DUMPING_FUNCTION" = "TRUE" ]
	then

		if [ "$DUMPING_FUNCTION" = "TRUE" ] && [ "$FUNC_FILTER_MODE" = "ASCII" ]
		then
			NO_TABS="$( echo $LINE | tr -s [:blank:] )"
			CUT_LEAD="${NO_TABS##*:}"
			CUT_LEAD_SPACE="${NO_TABS#* }"

			for EL in $CUT_LEAD_SPACE
			do
				if ! [ "${#EL}" -ne 2 ]
				then
					case $EL in
						''|*[0-9a-f][0-9a-f])

							if [ "$EL" = "0a" ]
							then
								echo -n "\\n"
							else
								echo -ne "\x$EL"
							fi
						;;
					esac
				fi
			done

			continue
		fi

		FINAL_AX=""

		case $LINE in

			*">:"*)
				CUT_TRAIL="${LINE%%>:*}"
				CURR_FUNC="${CUT_TRAIL##*<}"
			;;

			*"mov"*)
				case $LINE in

					*"%rax")
						CUT_TRAIL="${LINE%%,%rax}"
						PREV_RAX="${CUT_TRAIL##*\$}"
						FINAL_AX="$PREV_RAX"
					;;

					*"%eax")
						CUT_TRAIL="${LINE%%,%eax}"
						PREV_EAX="${CUT_TRAIL##*\$}"
						FINAL_AX="$PREV_RAX"
					;;
				esac

				if ! [ "$FINAL_AX" = "" ]
				then

					for SYSC in "${SYSCALLS[@]}"
					do
						SYSC_F="$SYSC"

						if [ "$(echo $SYSC | cut -c 1-1)" = "*"  ]
						then
							SYSC_F="${SYSC##*\*}"
						fi

						if [ "$(echo $SYSC_F | cut -c 1-2)" = "0x" ] && [ "$SYSC_F"  = "$FINAL_AX" ]
						then
							DUMPING_SYSCALL="TRUE"
						else
							case $SYSC_F in
								''|*[!0-9]*)
								;;
								*)
									if [ "$(($FINAL_AX))" = "$SYSC_F" ]
									then
										DUMPING_SYSCALL="TRUE"
									fi
								;;
							esac
						fi
						
						if [ "$DUMPING_SYSCALL" = "TRUE" ]
						then
							EAX_OR_RAX_OVERWRITTEN="FALSE"
							TEST_LINE_NUMBER=-1

							echo -ne "$CONTENTS\n" |
							while IFS= read -r TEST_LINE
							do
								((TEST_LINE_NUMBER++))
								if [ "$TEST_LINE_NUMBER" -le "$CURR_LINE_NUMBER" ]
								then
									continue
								fi

								case $TEST_LINE in
									*"mov"*)
										case $TEST_LINE in
											*"$rax")
												EAX_OR_RAX_OVERWRITTEN="TRUE"
											;;
											*"$eax")
												EAX_OR_RAX_OVERWRITTEN="TRUE"
											;;
										esac
									;;
									*"syscall"*)
										break
									;;
								esac
							done

							if [ "$EAX_OR_RAX_OVERWRITTEN" = "TRUE"  ]
							then
								DUMPING_SYSCALL="FALSE"
							else
								SYSC_FILTER_MODE="EMPHASIZE"
								echo -ne "$MARKER_SET"
							fi
						fi
					done
				fi
			;;

			*"syscall"*)

				if [ "$DUMPING_SYSCALL" = "TRUE" ]
				then
					if [ "$SYSC_FILTER_MODE" = "EMPHASIZE" ] && (! [ "$SECT_FILTER_MODE" = "EMPHASIZE" ] || [ "$DUMPING_SECTION" = "FALSE"  ]) && (! [ "$FUNC_FILTER_MODE" = "EMPHASIZE" ] || [ "$DUMPING_FUNCTION" = "FALSE"  ])
					then
						echo "$LINE"
						echo -ne "$MARKER_RESET"
						ECHO_LINE_BYPASS="TRUE"
					fi
					DUMPING_SYSCALL="FALSE"
				fi
			;;
		esac

		if [ "$ECHO_LINE_BYPASS" = "FALSE" ]
		then
			echo "$LINE"

		elif [ "$ECHO_LINE_BYPASS" = "TRUE" ]
		then
			ECHO_LINE_BYPASS="FALSE"
		fi

	fi
done

echo -ne "$MARKER_RESET"
echo -ne "\n"
