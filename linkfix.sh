#!/bin/bash

# installation:
# $ sudo chmod +x linkfix.sh
# $ sudo mv linkfix.sh /usr/local/bin/linkfix

# run linkfix in directory containing _pods.xcodeproj file

# get property1, property2 and property3, set property1 to value1 and property3 to value3 for pods from pod1 to podn
# linkfix "property1" "property2" "property1=value1" "property3=value3" "property3" -p "pod1" "pod2" "pod3" ... "podn"

# Example: undo changes
# linkfix -u

# Example: fix -fobjc-weak link errors
# linkfix "CLANG_ENABLE_OBJC_WEAK=NO" -p GMGridView iCarousel FlurrySDK

if [[ $# == 0 ]]
then
  echo -ne "\n\033[1mLinkfix\033[m - XCode linker tool\n\n"
  echo -ne "\033[1mInstallation\033[m\n\n"
  echo -ne "  $ sudo chmod +x linkfix.sh\n"
  echo -ne "  $ sudo mv linkfix.sh /usr/local/bin/linkfix\n\n"
  echo -ne "\033[1mUsage example\033[m\n\n"
  echo -ne "  $ linkfix PROP1 PROP2 PROP1=VAL1 PROP3=VAL3 -p Pod1 Pod2\n"
  echo -ne "    \033[2mGet properties PROP1 and PROP2, set PROP1 to VAL1 and PROP3"
  echo -ne "\n    to VAL3 for pods Pod1 and Pod2.\033[m\n\n"
  echo -ne "  $ linkfix -u\n"
  echo -ne "    \033[2mUndo last changes.\033[m\n\n"
  echo -ne "\033[1mConcrete example\033[m\n\n"
  echo -ne "  $ linkfix CLANG_ENABLE_OBJC_WEAK=NO -p GMGridView iCarousel FlurrySDK\n"
  echo -ne "    \033[2mFix -fobjc-weak link errors for GMGridView, iCarousel and FlurrySDK.\033[m\n\n"
  echo -ne "\033[1mUsage note\033[m\n\n"
  echo -ne "   Run linkfix in directory containing _Pods.xcodeproj file.\n\n"
  echo -ne "\033[1mAuthor\033[m\n\n"
  echo -ne "   Stjepan Poljak (2018)\n\n"
  echo -ne "\033[1mComments\033[m\n\n"
  echo -ne "   Use linkfix on your own responsibility. It should work, but it is still\n"
  echo -ne "   not well tested. Choosing debug or release for each pod is not supported,\n"
  echo -ne "   and probably never will be, unless there is a reasonable demand. You are\n"
  echo -ne "   free, however, to modify and distribute the source as you wish.\n\n"
  exit
else
  echo -ne "\nLinkfix, the XCode linker tool by Stjepan Poljak (2018).\n"
fi

PROJFILE="$(pwd)/_Pods.xcodeproj/project.pbxproj"
BACKFILE="$(pwd)/project.pbxproj.backup"
TEMPFILE="${BACKFILE/.backup/}.temp"

if [[ ! -f "$PROJFILE" ]]
then
  echo -e "\n(!) Could not find project file.\n"
  exit
fi

# undo logic

if [[ "$1" == "-u" ]]
then
  if [[ -f "$BACKFILE" ]]
  then
    echo -e "\nWill undo changes.\n"
    mv "$BACKFILE" "$PROJFILE"
  else
    echo -e "\n(!) Backup file not found. Oops.\n"
  fi
  exit
fi

# arguments logic

PODSINARGS=()
PROPSTOGET=()
PROPSTOSET=()
VALSTOSET=()

PODLIST=0
GETORSET=1

COLLEN=$(tput cols)

for arg in "$@"
do

  if [[ "$PODLIST" == "1" ]]
  then
    PODSINARGS+=("$arg")
  fi

  if [[ "$arg" == "-p" ]]
  then
    PODLIST=1
    GETORSET=0
    continue
  fi

  if [[ "$GETORSET" == "1" ]]
  then
    if [[ "$arg" =~ "=" ]]
    then
      PROPTMP="${arg%=*}"
      VALTMP="${arg#*=}"

      if [[ -z "$PROPTMP" ]] || [[ -z "$VALTMP" ]]
      then
        echo "Invalid argument: \"$arg\"".
        exit
      else
      	PROPSTOSET+=("$PROPTMP")
      	VALSTOSET+=("$VALTMP")
      fi
    else
      PROPSTOGET+=("$arg")
    fi
  fi

done

if [[ ! ${#PROPSTOGET} == 0 ]]
then
  printf "\n\033[1mWill get\033[m:\n"

  for pget in "${PROPSTOGET[@]}"
  do
    echo "  $pget"
  done
fi

if [[ ! ${#PROPSTOSET} == 0 ]]
then
  printf "\n\033[1mWill set\033[m:\n"

  PCNTSET=0 # number of setters

  for pset in "${PROPSTOSET[@]}"
  do
    echo "  $pset to ${VALSTOSET[$PCNTSET]}"
    (( PCNTSET++ ))
  done
fi

printf "\n\033[1mPods considered\033[m:\n"
for pod in "${PODSINARGS[@]}"
do
  echo "  $pod"
done

printf "\n"

# the saga begins here...

if [[ -f "$BACKFILE" ]]
then
  rm "$BACKFILE"
fi

# for debug

if [[ -f "$TEMPFILE" ]]
then
  rm "$TEMPFILE"
fi

printf "Creating backup file... "

cp "$PROJFILE" "$BACKFILE"

printf "Done!\n\n"

# vars for line parsing logic

CURRLINE=0
DEBUGORRELEASELINE=-1
ISALINE=-1
BASECONFIGLINE=-1
BUILDSETLINE=-1

# some other vars

DEBUGORRELEASE="" # can be "Debug" or "Release"
PODNAME="" # name of current pod we are considering in .pbxproj

FCONTOVERRIDE=0 # set to 1 if writing over existing properties
ANYSET=0 # if we changed some property, set this to 1 -> it will save the file

ERASEMODE=1 # honestly, I forgot the logic with this, but it works, so don't touch
LASTTABSNUM=0 # we want to know about tab characters, so our added lines are consistent

echo "Searching for pod build settings - this may take several seconds..."
echo ""

FOUNDPCNT=()

while IFS= read -r p || [[ -n "$p" ]]
do

  if [[ ! $BUILDSETLINE == -1 ]]
  then
    if [[ "$p" =~ "};" ]]
    then
      # we have reached the end of build settings for current pod
      # so let's also check what setter property was not found
      # during setting and add it here
      
      for currpod in "${PODSINARGS[@]}"
      do
        if [[ ! "$currpod" == "$PODNAME" ]]
        then
          continue
        fi

        if [[ ! $PCNTSET == 0 ]]
        then
          for pcnt in $( seq 0 $(( $PCNTSET - 1 )) )
          do
            WASFOUND=0
            for fnd in ${FOUND[@]}
            do
              if [[ $fnd == $pcnt ]]
              then
                WASFOUND=1
                break
              fi
            done
              if [[ $WASFOUND == 0 ]]
              then

                LINETOADD=""
                for tab in $( seq 0 $(( $LASTTABSNUM - 1 )) )
                do
                  LINETOADD+="\t"
                done

                LINETOADD+="${PROPSTOSET[$pcnt]} = ${VALSTOSET[$pcnt]};"
                
                if [[ $ERASEMODE == 1 ]]
                then
                  printf "\n\n"
                  ERASEMODE=0
                fi

                echo "Adding ${PROPSTOSET[$pcnt]} = ${VALSTOSET[$pcnt]}."
                echo -e "$LINETOADD" >> "$TEMPFILE"
                ANYSET=1
              fi
          done
        fi
      done

      unset FOUND
      FOUND=()

      ISALINE=-1
      BASECONFIGLINE=-1
      BUILDSETLINE=-1
      PODNAME=""
      DEBUGORRELEASELINE=-1
      DEBUGORRELEASE=""
    else

      for currpod in "${PODSINARGS[@]}"
      do
        # if the current pod does not correspond to some pod
        # in our -p list, skip...

        if [[ ! "$currpod" == "$PODNAME" ]]
        then
          continue
        fi
        
        # processing getters

        for getter in "${PROPSTOGET[@]}"
        do
          if [[ "$p" =~ "=" ]] && [[ "${p%=*}" =~ "$getter" ]]
          then

            if [[ $ERASEMODE == 1 ]]
            then
              printf "\n\n"
              ERASEMODE=0
            fi

            echo "${p//[[:space:]]/}"
          fi
        done

        if [[ $PCNTSET == 0 ]]
        then
          continue
        fi
        
        # find the number of first repeating tab characters

        LEADTRIM="$( echo -e "${p}" | sed -e 's/^[[:space:]]*//' )"
        LEADTRIMLEN=${#LEADTRIM}
        LINELEN=${#p}

        LASTTABSNUM=$(( LINELEN - LEADTRIMLEN ))

        # here we process setters

        for pcnt in $( seq 0 $(( $PCNTSET - 1 )) )
        do
          if [[ "$p" =~ "=" ]] && [[ "${p%=*}" =~ "${PROPSTOSET[$pcnt]}" ]]
          then
            if [[ $ERASEMODE == 1 ]]
            then
              printf "\n\n"
              ERASEMODE=0
            fi
            FOUND+=( $pcnt )
            echo "Setting ${PROPSTOSET[$pcnt]} to ${VALSTOSET[$pcnt]}."
            echo -e "${p%=*}= ${VALSTOSET[$pcnt]};" >> "$TEMPFILE"
            FCONTOVERRIDE=1
            ANYSET=1
          fi
        done
      done
    fi
  fi

  if [[ ! $BASECONFIGLINE == -1 ]]
  then
    if [[ "$p" =~ "buildSettings" ]]
    then

      RESULT="> Opening build settings for: $PODNAME"

      if [[ DEBUGORRELEASELINE > "$(( $ISALINE - 5 ))" ]]
      then
        RESULT+=" ($DEBUGORRELEASE)"
      fi

      BUILDSETLINE="$CURRLINE"
      
      if [[ $ERASEMODE == 0 ]]
      then
        ERASEMODE=1
        printf "\n"
      fi

      STRLEN=${#RESULT}
      (( STRLEN ++ ))

      printf '\r%s' "$RESULT"
      printf ' %.0s' $( seq $STRLEN $COLLEN )

    fi
  fi

  if [[ ! $ISALINE == -1 ]]
  then
    if [[ "$p" =~ "baseConfigurationReference" ]]
    then
      BASECONFIGLINE="$CURRLINE"
      PAT1="${p#*\*}"
      PAT2="${PAT1%.xcconfig*}"
      PODNAME="${PAT2// /}";
    else
      ISALINE=-1
    fi
  fi

  if [[ "$p" =~ "XCBuildConfiguration" ]] && [[ "$p" =~ "isa" ]]
  then
    ISALINE="$CURRLINE"
  fi

  if [[ "$p" =~ "Debug" ]]
  then
    DEBUGORRELEASE="Debug"
    DEBUGORRELEASELINE="$CURRLINE"
  fi

  if [[ "$p" =~ "Release" ]]
  then
    DEBUGORRELEASE="Release"
    DEBUGORRELEASELINE="$CURRLINE"
  fi

  (( CURRLINE ++ ))

  if [[ $PCNTSET > 0 ]]
  then
    if [[ $FCONTOVERRIDE == 0 ]]
    then
      echo -e "$p" >> "$TEMPFILE"
    else
  	  FCONTOVERRIDE=0
    fi
  fi

done < "$PROJFILE"

printf '\r'
printf ' %.0s' $( seq 1 $COLLEN )
printf '\r'

if [[ $ANYSET == 0 ]]
then
  printf "No changes were made.\n\n"
else
  printf "Saving changes to project file... "
  mv "$TEMPFILE" "$PROJFILE"
  printf "Done!\n\n"
fi