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
	local inputBranch="$1"
	local inputBranchNames=("$inputBranch" "$(GetBranchFullName $inputBranch)")
	local allBranches="$(git branch | sed -E 's/(^(\*?)[ \t]+)|([ \t]+$)//g')"
	for branchName in ${inputBranchNames[@]}; do
		# Check whether the provided branch exists
		local existingBranchName=$(echo "$allBranches" | egrep -o "^$branchName\$")
		if [ -n "$existingBranchName" ] && (( $(echo "$existingBranchName" | grep -c '') == 1 )); then
			echo $existingBranchName
			return
		fi
	done
}

function BranchCountOnRemoteOrigin() {
	local branchName="$1"
	local existingBranchName=$(GetExistingBranchName "$branchName")
	local remoteBranchCount=$(git branch -a | egrep -c "^\s*remotes/origin/$existingBranchName$")
	echo "$remoteBranchCount"
}

function UpdateBranchesInfoFromRemote() {
	RunGitCommandSafely "git fetch -pq > /dev/null"
}

function GetCurrentBranchName() {
	currentBranchName=$(git rev-parse --abbrev-ref HEAD)
	if [ -z "$currentBranchName" ]; then
		ScriptFailure "Unable to get current Git branch name"
	fi
	echo "$currentBranchName"
}

export -f RunGitCommandSafely
export -f GetBranchFullName
export -f GetExistingBranchName
export -f BranchCountOnRemoteOrigin
export -f UpdateBranchesInfoFromRemote
