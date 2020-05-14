#!/bin/bash

LogSuccess() { echo -e "\e[92m$1\e[0m"; }
LogWarning() { echo -e "\e[33m$1\e[0m"; }
LogError() { >&2 echo -e "\e[31m$1\e[0m"; }

RunGitCommandSafely() {
	eval $1
	local execStatus=$?
	if (( execStatus != 0 ))
	then
		LogError "Command [$1] failed with $execStatus" 
		if (( $# >= 2 )) && (( $2 > 0 ))
		then
			LogWarning "Remember to run 'git stash pop' to restore $2 changed files"
		fi
		exit $execStatus
	else
		LogSuccess "Command [$1] successful" 
	fi
}
