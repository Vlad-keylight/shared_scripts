#!/bin/bash

currentScriptFolderName=$(dirname "$0")
currentScriptFileName=$(basename "$0")
# Include common helper functions
. "$currentScriptFolderName/_git_common.sh" --source-only

branchName=$1
if [ -z "$branchName" ]
then
	ScriptFailure "Branch name is required\n$currentScriptFileName \$1:BRANCH_NAME"
fi

# Stash initial changes to enable pull/merge/checkout
gitFilesChanged=$(git status -su | grep -c '')
if (( $gitFilesChanged == 0 ))
then
	LogSuccess "No files changed -> no stashing"
else
	LogWarning "Stashing $gitFilesChanged changed files"
	RunGitCommandSafely "git stash --include-untracked"
fi

RunGitCommandSafely "git fetch" $gitFilesChanged

# Reset all commits worked on the current branch
RunGitCommandSafely "git reset --hard origin/master" $gitFilesChanged

gitUser=$(git config credential.username)
if [ "$gitUser" = "" ]
then
	gitUser=$USERNAME
fi

# Check whether the provided branch exists
existingBranchName=$(git branch | sed -E 's/(^(\*?)[ \t]+)|([ \t]+$)//g' | egrep -o "^(($gitUser/)?)$branchName\$")
if [ -z "$existingBranchName" ]; then
	# Prefix the branch name with the username before creating it,
	# if it isn't already prefixed properly
	if [[ "$branchName" != $gitUser/* ]]
	then
		branchName="$gitUser/$branchName"
	fi

	if [ -n "$(ConfirmAction Create new branch [$branchName])" ]; then
		RunGitCommandSafely "git checkout -b $branchName" $gitFilesChanged
		LogSuccess "Successfully created new branch [$branchName]"
	else
		LogWarning "Skipped creating new branch [$branchName]"
	fi
else
	branchName=$existingBranchName
	LogWarning "Switching to existing branch [$branchName]"
	RunGitCommandSafely "git checkout $branchName" $gitFilesChanged
	if [ -n "$(git branch -a | grep \"remotes/origin/$branchName\")" ]; then
		RunGitCommandSafely "git pull" $gitFilesChanged
	else
		LogWarning "Branch [$branchName] does not exist in remote origin. Skipping pull."
	fi
	LogSuccess "Successfully switched to existing branch [$branchName]"
fi

# Remove all non-versioned files and directories
# git clean -f -d

# Stash pop initial changes
if (( $gitFilesChanged > 0 ))
then
	RunGitCommandSafely "git stash pop" $gitFilesChanged
fi
