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

# Check whether the provided branch exists
existingBranchName=$(GetExistingBranchName $branchName)
if [ -z "$existingBranchName" ]; then
	branchName=$(GetBranchFullName $branchName)
	
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
	if [ -n "$(git branch -a | grep remotes/origin/$branchName)" ]; then
		RunGitCommandSafely "git pull" $gitFilesChanged
	else
		LogWarning "Branch [$branchName] does not exist in remote origin. Skipping pull."
	fi
	LogSuccess "Successfully switched to existing branch [$branchName]"
fi

# Stash pop initial changes
if (( $gitFilesChanged > 0 ))
then
	RunGitCommandSafely "git stash pop" $gitFilesChanged
fi
