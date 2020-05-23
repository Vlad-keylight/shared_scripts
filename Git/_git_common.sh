#!/bin/bash

currentScriptFolderName=$(dirname "$0")
currentScriptFileName=$(basename "$0")
# Include common helper functions
. "$currentScriptFolderName/../_common.sh" --source-only

RunGitCommandSafely() {
	eval $1
	local execStatus=$?
	if (( execStatus != 0 ))
	then
		if (( $# >= 2 )) && (( $2 > 0 ))
		then
			LogWarning "Remember to run 'git stash pop' to restore $2 changed files"
		fi
		ScriptExit $execStatus "Command [$1] failed with $execStatus" 
	else
		LogSuccess "Command [$1] successful" 
	fi
}
