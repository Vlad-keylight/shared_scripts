#!/bin/bash

currentScriptFolderName=$(dirname "$0")
currentScriptFileName=$(basename "$0")
# Include common helper functions
. "$currentScriptFolderName/_git_common.sh" --source-only

latestLocalPackageUpdateCommit() {
	git log -n 1 --oneline -- package-lock.json package.json
}

# Get current git branch
gitInitialBranch=$(git rev-parse --abbrev-ref HEAD)
if [ -z "$gitInitialBranch" ]
then
	ScriptFailure "Unable to get the current git branch"
fi

# Update list of branches from remote origin
RunGitCommandSafely "git fetch -p"

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
	targetGitInitialBranch=$(GetExistingBranchName $1)
	if [ "$targetGitInitialBranch" == "$gitInitialBranch" ]
	then
		LogSuccess "Already on target branch [$targetGitInitialBranch]"
	else
		RunGitCommandSafely "git checkout $targetGitInitialBranch"
		gitInitialBranch=$targetGitInitialBranch
	fi
fi

packageUpdateCommitBefore=$(latestLocalPackageUpdateCommit)

mergeSourceBranchName="master"
if [ -n "$2" ] && [ "$2" != "$gitInitialBranch" ]; then
	mergeSourceBranchName=$(GetExistingBranchName $2)
fi

# If we aren't already on the merge source branch then switch
if [[ "$gitInitialBranch" != "$mergeSourceBranchName" ]]
then
	RunGitCommandSafely "git checkout $mergeSourceBranchName" $gitFilesChanged
fi

# Update the branch (pull new changes)
RunGitCommandSafely "git pull > /dev/null" $gitFilesChanged

# If we weren't initially on merge source branch then switch back and merge
if [[ "$gitInitialBranch" != "$mergeSourceBranchName" ]]
then
	RunGitCommandSafely "git checkout $gitInitialBranch" $gitFilesChanged
	RunGitCommandSafely "git merge $mergeSourceBranchName > /dev/null" $gitFilesChanged
fi

# Stash pop initial changes
if (( $gitFilesChanged > 0 ))
then
	RunGitCommandSafely "git stash pop" $gitFilesChanged
fi

LogSuccess "Successfully updated branch [$gitInitialBranch] from [$mergeSourceBranchName]"

# Run `npm install` only if there was a package update in the latest pull/merge 
packageUpdateCommitAfter=$(latestLocalPackageUpdateCommit)
if [ "$packageUpdateCommitBefore" != "$packageUpdateCommitAfter" ]; then
	RunGitCommandSafely "npm install"
fi
