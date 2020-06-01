#!/bin/bash

currentScriptFolderName=$(dirname "$0")
currentScriptFileName=$(basename "$0")
# Include common helper functions
. "$currentScriptFolderName/../_common.sh" --source-only

function RunGitCommandSafely() {
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

function GetBranchFullName() {
	function getGitUserName() {
		local gitUserName=$(git config credential.username)
		if [ -z "$gitUserName" ]
		then
			echo $gitUserName
		else
			echo $USERNAME
		fi
	}

	local branchName=$1
	# Prefix the branch name with the username before creating it,
	# if it isn't already prefixed properly
	local gitUserName=$(getGitUserName)
	if [[ "$branchName" != $gitUserName/* ]]
	then
		echo "$gitUserName/$branchName"
	else
		echo "$branchName"
	fi
}

function GetExistingBranchName() {
	local branchName="$1"
	# Check whether the provided branch exists
	local branches="$(git branch | sed -E 's/(^(\*?)[ \t]+)|([ \t]+$)//g')"
	local existingBranchName=$(echo "$branches" | egrep -o "^$branchName\$")
	if [ -n "$existingBranchName" ]; then
		echo $existingBranchName
	else
		# Fallback to checking branch full name
		local branchFullName=$(GetBranchFullName $branchName)
		echo "$branches" | egrep -o "^$branchFullName\$"
	fi
}

function BranchCountOnRemoteOrigin() {
	local branchName="$1"
	local existingBranchName=$(GetExistingBranchName "$branchName")
	local remoteBranchCount=$(git branch -a | egrep -c "^\s*remotes/origin/$existingBranchName$")
	echo "$remoteBranchCount"
}

export -f RunGitCommandSafely
export -f GetBranchFullName
export -f GetExistingBranchName
export -f BranchCountOnRemoteOrigin
