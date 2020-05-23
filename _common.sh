#!/bin/bash

LogCounter=0;
function LogWithFormat() {
	local format=$1
	local message="${@:2}"
	echo -e "\e[${format}m${message}\e[0m"
}

function LogInfo() { LogWithFormat 0 "$@"; }
function LogSuccess() { LogWithFormat 32 "$@"; }
function LogCheck() { LogWithFormat 93 "$@"; }
function LogWarning() { LogWithFormat 33 "$@"; }
function LogError() { LogWithFormat 31 "$@"; }
function ScriptExit() {
	local exitStatus="$1"
	local message="${@:2}"
	if (( "$exitStatus" == 0 )); then
		LogSuccess "$message"
	else
		LogError "$message"
	fi
	exit $exitStatus 
}
function ScriptFailure() { ScriptFailureStatus 1 "$@"; }

function ConfirmAction() {
	# if [ -n "$(ConfirmAction Your question here)" ]; then Dangerous action here; fi
	local questionMessage=$(LogCheck "$@ (y/N) ? ")
	read -p "$questionMessage" -r
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		# Any non-empty output will do
		echo "Fly, you fools!"
	fi
}

function CopyFileSafely() {
	local sourceFilePath="$1"
	local destDirectory="$2"

	local copyFileName=$(basename "$sourceFilePath")
	local destFilePath="$destDirectory/$copyFileName"

	if [ -s "$destFilePath" ]; then
		if [ -z "$(ConfirmAction Overwrite existing [$copyFileName])" ]; then
			LogWarning "Skipping copy of [$copyFileName]"
			return
		fi
	fi

	LogSuccess "Copying file [$copyFileName]"
	cp "$sourceFilePath" "$destFilePath"
}

export -f LogWithFormat
export -f LogSuccess
export -f LogWarning
export -f LogCheck
export -f LogError
export -f ScriptFailureStatus
export -f ScriptFailure
export -f ConfirmAction
export -f CopyFileSafely
