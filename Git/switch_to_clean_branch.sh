#!/bin/bash

. $(dirname "$0")/_git_common.sh --source-only

branchName=$1
if [ "$branchName" = "" ]
then
	echo "Branch name is required"
	exit 1
fi

gitUser=$(git config credential.username)
if [ "$gitUser" = "" ]
then
	gitUser=$USERNAME
fi

# Prefix the branch name with the username
if [[ "$branchName" != $gitUser/* ]]
then
    branchName="$gitUser/$branchName"
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

branchRef=$(git rev-parse --verify --quiet $branchName)
if [ "$branchRef" = "" ]; then
	LogWarning "Creating new branch [$branchName]"
	RunGitCommandSafely "git checkout -b $branchName" $gitFilesChanged
else
	LogWarning "Switching to existing branch [$branchName]"
	RunGitCommandSafely "git checkout $branchName" $gitFilesChanged
	RunGitCommandSafely "git pull" $gitFilesChanged
fi

# Remove all non-versioned files and directories
# git clean -f -d

# Stash pop initial changes
if (( $gitFilesChanged > 0 ))
then
	RunGitCommandSafely "git stash pop" $gitFilesChanged
fi

LogSuccess "Successfully switched to clean branch [$branchName]"
