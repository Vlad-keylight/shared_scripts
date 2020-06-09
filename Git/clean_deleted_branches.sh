#!/bin/bash

currentScriptFolderName=$(dirname "$0")
currentScriptFileName=$(basename "$0")
# Include common helper functions
. "$currentScriptFolderName/_git_common.sh" --source-only

# Update list of branches from remote origin
UpdateBranchesInfoFromRemote

# List all branches & filter only the branches deleted from the remote origin
deletedBranchRegex="((: )|(\[))gone\]"
currentBranchDeleted=$(git branch --verbose | awk "/\*.*$deletedBranchRegex/{print \$2}")
if [ -n "$currentBranchDeleted" ]; then
	# Switch to master branch to enable deletion of the current branch
	# which is deleted from the remote origin
	LogWarning "Switching away from current branch [$currentBranchDeleted] which is deleted from the remote origin"
	RunGitCommandSafely "git checkout master"
fi

allDeletedBranches=$(git branch --verbose | awk "/$deletedBranchRegex/{print \$1}")
if [ -n "$allDeletedBranches" ]; then
	LogWarning "Cleaning $(echo "$allDeletedBranches" | grep -c '') deleted remote branches"
	# Clean the remotely deleted branches, force to avoid asking for confirmation
	echo "$allDeletedBranches" | xargs git branch -df
else
	LogSuccess "No deleted remote branches to clean locally"
fi
