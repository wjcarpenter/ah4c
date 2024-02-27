#!/bin/bash
#bmitune.sh for chromecast/npo

#Debug on if uncommented
set -x

#Global
channelID=\""$1\""
specialID="$1"
streamerIP="$2"
streamerNoPort="${streamerIP%%:*}"
adbTarget="adb -s $streamerIP"
packageName=nl.uitzendinggemist
m3uName="${STREAMER_APP#*/*/}.m3u"

#Trap end of script run
finish() {
  echo "bmitune.sh is exiting for $streamerIP with exit code $?"
}

trap finish EXIT

updateReferenceFiles() {

  # Handle cases where stream_stopped or last_channel don't exist
  mkdir -p $streamerNoPort
  [[ -f "$streamerNoPort/stream_stopped" ]] || echo 0 > "$streamerNoPort/stream_stopped"
  [[ -f "$streamerNoPort/last_channel" ]] || echo 0 > "$streamerNoPort/last_channel"

  # Write PID for this script to bmitune_pid for use in stopbmitune.sh
  echo $$ > "$streamerNoPort/bmitune_pid"
  echo "Current PID for this script is $$"
}

#Set encoderURL based on the value of streamerIP
matchEncoderURL() {

  case "$streamerIP" in
    "$TUNER1_IP")
      encoderURL=$ENCODER1_URL
      ;;
    "$TUNER2_IP")
      encoderURL=$ENCODER2_URL
      ;;
    "$TUNER3_IP")
      encoderURL=$ENCODER3_URL
      ;;
    "$TUNER4_IP")
      encoderURL=$ENCODER4_URL
      ;;
    *)
      exit 1
      ;;
  esac
}

#Check for active audio stream with maxDuration, preTuneAudioCheck, sleepBeforeAudioCheck and sleepAfterAudioCheck as arguments
activeAudioCheck() {
  local startTime=$(date +%s)
  local maxDuration=$1
  local minimumLoudness=-50
  local sleepBeforeAudioCheck=$3
  local sleepAfterAudioCheck=$4
  local preTuneAudioCheck=$2
  
  while true; do
    sleep $sleepBeforeAudioCheck
    checkLoudness=$(ffmpeg -t 1 -i $encoderURL -filter:a ebur128 -map 0:a -f null -hide_banner - 2>&1 | awk '/I:        /{print $2}')

    if (( $(date +%s) - $startTime > $maxDuration )); then
      echo "Active audio stream not detected in $maxDuration seconds."
      if [ $preTuneAudioCheck = "false" ]; then
        echo "Active audio stream not detected after tuning completed"
        case "$specialID" in
          "212")
            echo "Possible sports event blackout on NFL Network, so bumping channel up"
            $adbTarget shell input keyevent KEYCODE_DPAD_LEFT
            echo 0 > "$streamerNoPort/last_channel"
            exit 1
            ;; 
          "213")
            echo "Possible sports event blackout on MLB Network, so bumping channel down"
            $adbTarget shell input keyevent KEYCODE_DPAD_RIGHT
            echo 0 > "$streamerNoPort/last_channel"
            exit 1
            ;; 
          *)
            echo "Possible sports event blackout, so bumping channel down"
            $adbTarget shell input keyevent KEYCODE_DPAD_RIGHT
            echo 0 > "$streamerNoPort/last_channel"
            exit 1
            ;;
        esac
      else
        exit 1
      fi
    fi

    if (( $(echo "$checkLoudness > $minimumLoudness" | bc -l) )); then
      echo "Active audio stream detected with $checkLoudness LUF."
      break
    fi

    echo "Active audio stream not yet detected -- loudness is $checkLoudness LUF. Continuing..."
    sleep $sleepAfterAudioCheck
  done
}

#Special channels to kill DirecTV app or reboot FireStick
specialChannels() {

    if [ $specialID = "exit" ]; then
      echo "Exit $packageName requested on $streamerIP"
      rm $streamerNoPort/last_channel $streamerNoPort/adbAppRunning
      $adbTarget shell am force-stop $packageName
      exit 0
    elif [ $specialID = "reboot" ]; then
      echo "Reboot $streamerIP requested"
      rm $streamerNoPort/last_channel $streamerNoPort/adbAppRunning
      $adbTarget reboot
      exit 0
    elif [[ -f $streamerNoPort/adbCommunicationFail ]]; then
      rm $streamerNoPort/adbCommunicationFail
      exit 1
    else
      echo "Not a special channel (exit nor reboot)"
      appFocus=$($adbTarget shell dumpsys window windows | grep -E 'mCurrentFocus' | cut -d '/' -f1 | sed 's/.* //g')
      echo "Current app in focus is $appFocus" 
    fi
}

#Variable delay based on whether app was running or needed to be launched
#and whether less than maxTime seconds (maxTime/3600 for hours) has passed while sleeping
launchDelay() {
  local lastChannel
  local lastAwake
  local timeNow
  local timeElapsed
  local maxTime=14400

  lastChannel=$(<"$streamerNoPort/last_channel")
  lastAwake=$(<"$streamerNoPort/stream_stopped")
  timeNow=$(date +%s)
  timeElapsed=$(($timeNow - $lastAwake))

  if (( $lastChannel == $specialID )) && (( $timeElapsed < $maxTime )); then
    echo "Last channel selected on this tuner, no channel change required"
    exit 0
  elif [ -f $streamerNoPort/adbAppRunning ] && (( $timeElapsed < $maxTime )); then
    activeAudioCheck 42 true 0 1 # (maxDuration, preTuneAudioCheck, sleepBeforeAudioCheck, sleepAfterAudioCheck)
    #sleep 14
    rm $streamerNoPort/adbAppRunning
    echo $specialID > "$streamerNoPort/last_channel"
  else
    activeAudioCheck 42 true 0 1 # (maxDuration, preTuneAudioCheck, sleepBeforeAudioCheck, sleepAfterAudioCheck)
    #sleep 32
    echo $specialID > "$streamerNoPort/last_channel"
  fi
}

#Tuning is based on channel name values from $m3uName.
tuneChannel() {
  case "$specialID" in
    "NPO1")
    echo "Tuning to special channel NPO1"
	$adbTarget shell input keyevent KEYCODE_BUTTON_B
	sleep 3
    $adbTarget shell input keyevent KEYCODE_DPAD_DOWN
#	sleep 1
	$adbTarget shell input keyevent KEYCODE_DPAD_DOWN
#	sleep 1
	$adbTarget shell input keyevent KEYCODE_DPAD_CENTER
	sleep 4
	$adbTarget shell input keyevent KEYCODE_DPAD_CENTER
    ;; 
    "NPO2")
    echo "Tuning to special channel NPO2"
	$adbTarget shell input keyevent KEYCODE_BUTTON_B
	sleep 3
	$adbTarget shell input keyevent KEYCODE_DPAD_DOWN
	$adbTarget shell input keyevent KEYCODE_DPAD_DOWN
	$adbTarget shell input keyevent KEYCODE_DPAD_CENTER
	sleep 4
	$adbTarget shell input keyevent KEYCODE_DPAD_RIGHT
	$adbTarget shell input keyevent KEYCODE_DPAD_RIGHT
	sleep 1
	$adbTarget shell input keyevent KEYCODE_DPAD_CENTER
    ;; 
    "NPO3")
    echo "Tuning to special channel NPO3"
	$adbTarget shell input keyevent KEYCODE_BUTTON_B
	sleep 3
	$adbTarget shell input keyevent KEYCODE_DPAD_DOWN
	$adbTarget shell input keyevent KEYCODE_DPAD_DOWN
	$adbTarget shell input keyevent KEYCODE_DPAD_CENTER
	sleep 4
	$adbTarget shell input keyevent KEYCODE_DPAD_RIGHT
	$adbTarget shell input keyevent KEYCODE_DPAD_RIGHT
	$adbTarget shell input keyevent KEYCODE_DPAD_RIGHT
	$adbTarget shell input keyevent KEYCODE_DPAD_RIGHT
	sleep 1
	$adbTarget shell input keyevent KEYCODE_DPAD_CENTER
    ;; 
    "NPO1ex")
    echo "Tuning to special channel NPO1 Extra"
	$adbTarget shell input keyevent KEYCODE_BUTTON_B
	sleep 3
	$adbTarget shell input keyevent KEYCODE_DPAD_DOWN
	$adbTarget shell input keyevent KEYCODE_DPAD_DOWN
	$adbTarget shell input keyevent KEYCODE_DPAD_CENTER
	sleep 4
	$adbTarget shell input keyevent KEYCODE_DPAD_RIGHT
	$adbTarget shell input keyevent KEYCODE_DPAD_RIGHT
	$adbTarget shell input keyevent KEYCODE_DPAD_RIGHT
	sleep 1
	$adbTarget shell input keyevent KEYCODE_DPAD_RIGHT
	$adbTarget shell input keyevent KEYCODE_DPAD_RIGHT
	$adbTarget shell input keyevent KEYCODE_DPAD_RIGHT
	sleep 1
	$adbTarget shell input keyevent KEYCODE_DPAD_CENTER
    ;; 
    "NPO2ex")
	$adbTarget shell input keyevent KEYCODE_BUTTON_B
	sleep 3
	$adbTarget shell input keyevent KEYCODE_DPAD_DOWN
	$adbTarget shell input keyevent KEYCODE_DPAD_DOWN
	$adbTarget shell input keyevent KEYCODE_DPAD_CENTER
	sleep 4
	$adbTarget shell input keyevent KEYCODE_DPAD_RIGHT
	$adbTarget shell input keyevent KEYCODE_DPAD_RIGHT
	$adbTarget shell input keyevent KEYCODE_DPAD_RIGHT
	$adbTarget shell input keyevent KEYCODE_DPAD_RIGHT
	sleep 1
	$adbTarget shell input keyevent KEYCODE_DPAD_RIGHT
	$adbTarget shell input keyevent KEYCODE_DPAD_RIGHT
	$adbTarget shell input keyevent KEYCODE_DPAD_RIGHT
	sleep 1
	$adbTarget shell input keyevent KEYCODE_DPAD_CENTER
    ;; 
    "NPO3ex")
	$adbTarget shell input keyevent KEYCODE_BUTTON_B
	sleep 3
	$adbTarget shell input keyevent KEYCODE_DPAD_DOWN
	$adbTarget shell input keyevent KEYCODE_DPAD_DOWN
	$adbTarget shell input keyevent KEYCODE_DPAD_CENTER
	sleep 4
	$adbTarget shell input keyevent KEYCODE_DPAD_RIGHT
	$adbTarget shell input keyevent KEYCODE_DPAD_RIGHT
	$adbTarget shell input keyevent KEYCODE_DPAD_RIGHT
	sleep 1
	$adbTarget shell input keyevent KEYCODE_DPAD_RIGHT
	$adbTarget shell input keyevent KEYCODE_DPAD_RIGHT
	sleep 1
	$adbTarget shell input keyevent KEYCODE_DPAD_RIGHT
	$adbTarget shell input keyevent KEYCODE_DPAD_RIGHT
	$adbTarget shell input keyevent KEYCODE_DPAD_RIGHT
	sleep 1
	$adbTarget shell input keyevent KEYCODE_DPAD_CENTER
    ;; 
  esac
}

main() {
  updateReferenceFiles
  matchEncoderURL
#  specialChannels
#  launchDelay
  tuneChannel
#  activeAudioCheck 24 false 5 1 # (maxDuration, preTuneAudioCheck, sleepBeforeAudioCheck, sleepAfterAudioCheck)
}

main
prebmitune

#!/bin/bash
#prebmitune.sh for chromecast/npo

#Debug on if uncommented
set -x

streamerIP="$1"
streamerNoPort="${streamerIP%%:*}"
adbTarget="adb -s $streamerIP"

mkdir -p $streamerNoPort

#Trap end of script run
finish() {
  echo "prebmitune.sh is exiting for $streamerIP with exit code $?"
}

trap finish EXIT

adbConnect() {
  adb connect $streamerIP

  local -i adbMaxRetries=25
  local -i adbCounter=0

  while true; do
    $adbTarget shell input keyevent KEYCODE_WAKEUP
    local adbEventSuccess=$?

    if [[ $adbEventSuccess -eq 0 ]]; then
      break
    fi

    if (($adbCounter > $adbMaxRetries)); then
      touch $streamerNoPort/adbCommunicationFail
      echo "Communication with $streamerIP failed after $adbMaxRetries retries"
      exit 1
    fi

    sleep 1
    ((adbCounter++))
  done
}

adbWake() {
  packageLaunch=".tv.presentation.splash.StartupActivity"
  packageName="nl.uitzendinggemist"
  packagePID=$($adbTarget shell pidof $packageName)
  
  if [ ! -z $packagePID ]; then
    $adbTarget shell input keyevent KEYCODE_WAKEUP
    $adbTarget shell am start -a android.intent.action.VIEW -n $packageName/$packageLaunch
    echo "Waking $streamerIP"
    touch $streamerNoPort/adbAppRunning
  else
    $adbTarget shell input keyevent KEYCODE_WAKEUP
    $adbTarget shell am start -a android.intent.action.VIEW -n $packageName/$packageLaunch
    echo "Starting $packageName on $streamerIP"
  fi
}

main() {
  adbConnect
  adbWake
  sleep 10
}

main
