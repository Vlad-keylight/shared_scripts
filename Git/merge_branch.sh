#!/bin/bash

currentScriptFolderName=$(dirname "$0")
currentScriptFileName=$(basename "$0")
# Include common helper functions
. "$currentScriptFolderName/_git_common.sh" --source-only

latestLocalPackageUpdateCommit() {
	git log -n 1 --oneline -- package-lock.json package.json
}

# Get current git branch
gitInitialBranch=$(GetCurrentBranchName)

# Update list of branches from remote origin
UpdateBranchesInfoFromRemote

# Stash initial changes to enable pull/merge/checkout
gitFilesChanged=$(git status -su | grep -c '')
if (( $gitFilesChanged == 0 ))
then
	LogSuccess "No files changed -> no stashing"
else
	LogWarning "Stashing $gitFilesChanged changed files"
	RunGitCommandSafely "git stash --include-untracked"
fi

packageUpdateCommitBefore=$(latestLocalPackageUpdateCommit)

mergeSourceBranchName="master"
if [ -n "$1" ] && [ "$1" != "$gitInitialBranch" ]; then
	mergeSourceBranchName=$(GetExistingBranchName $1)
	if [ -z "$mergeSourceBranchName" ]; then
		mergeSourceBranchName="$1"
	fi
fi

# If we aren't already on the merge source branch then switch
pullBranchName=$gitInitialBranch
if [[ "$gitInitialBranch" != "$mergeSourceBranchName" ]]
then
	RunGitCommandSafely "git checkout $mergeSourceBranchName" $gitFilesChanged
	pullBranchName=$mergeSourceBranchName
fi
if (( "$(BranchCountOnRemoteOrigin $pullBranchName)" == 0 )); then
	# Branch does not exist on the remote origin - we cannot perform git pull
	LogWarning "git pull not possible for local branch [$pullBranchName]"
else
	# Update the branch (pull new changes)
	RunGitCommandSafely "git pull -q > /dev/null" $gitFilesChanged
fi

# If we weren't initially on merge source branch then switch back and merge
if [[ "$gitInitialBranch" != "$mergeSourceBranchName" ]]
then
	RunGitCommandSafely "git checkout $gitInitialBranch" $gitFilesChanged
	RunGitCommandSafely "git merge $mergeSourceBranchName > /dev/null" $gitFilesChanged
	if [ -n "$(ConfirmAction Rebase to $mergeSourceBranchName and reset/squash other committed changes visible in the PR)" ]; then
		RunGitCommandSafely "git rebase origin/$mergeSourceBranchName" $gitFilesChanged
		RunGitCommandSafely "git push --force" $gitFilesChanged
	fi
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
