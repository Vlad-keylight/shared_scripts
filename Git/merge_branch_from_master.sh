#!/bin/bash

# Include common helper functions
. $(dirname "$0")/_git_common.sh --source-only

latestLocalPackageUpdateCommit() {
	git log -n 1 --oneline -- package-lock.json package.json
}

# Get current git branch
gitInitialBranch=$(git rev-parse --abbrev-ref HEAD)
if [ -z "$gitInitialBranch" ]
then
	ScriptFailure "Unable to get the current git branch"
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

# Check whether we have provided a branch name as a script parameter
if [ -n "$1" ]
then
	if [ "$1" == "$gitInitialBranch" ]
	then
		LogSuccess "Already on target branch [$1]"
	else
		RunGitCommandSafely "git checkout $1"
		gitInitialBranch=$1
	fi
fi

packageUpdateCommitBefore=$(latestLocalPackageUpdateCommit)

# If we aren't already on master then switch
if [[ "$gitInitialBranch" != "master" ]]
then
	RunGitCommandSafely "git checkout master" $gitFilesChanged
fi

# Update the branch (pull new changes)
RunGitCommandSafely "git pull > /dev/null" $gitFilesChanged

# If we weren't initially on master then switch back and merge
if [[ "$gitInitialBranch" != "master" ]]
then
	RunGitCommandSafely "git checkout $gitInitialBranch" $gitFilesChanged
	RunGitCommandSafely "git merge master > /dev/null" $gitFilesChanged
fi

# Stash pop initial changes
if (( $gitFilesChanged > 0 ))
then
	RunGitCommandSafely "git stash pop" $gitFilesChanged
fi

LogSuccess "Successfully updated branch [$gitInitialBranch]"

# Run `npm install` only if there was a package update in the latest pull/merge 
packageUpdateCommitAfter=$(latestLocalPackageUpdateCommit)
if [ "$packageUpdateCommitBefore" != "$packageUpdateCommitAfter" ]; then
	RunGitCommandSafely "npm install"
fi
