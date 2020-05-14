#!/bin/bash

. $(dirname "$0")/_git_common.sh --source-only

# Update list of branches from remote origin
RunGitCommandSafely "git fetch -p"

# list all branches
# 	remove the leading * for the current branch
# 	filter only the branches deleted from the remote origin
# 	delete the branches, force to avoid asking for confirmation
deletedBranchRegex="((: )|(\[))gone\]"
currentBranchDeleted=$(git branch --verbose | egrep -o "^\*.*$deletedBranchRegex")
if [ -n "$currentBranchDeleted" ]; then
	# Switch to master branch to enable deletion of the current branch
	# which is deleted from the remote origin
	LogWarning "Switching away from current branch which is deleted from the remote origin"
	RunGitCommandSafely "git checkout master"
fi

deletedBranches=$(git branch --verbose | awk "/$deletedBranchRegex/{print \$1}")
if [ -n "$deletedBranches" ]; then
	LogWarning "Cleaning $(echo "$deletedBranches" | grep -c '') deleted remote branches"
	echo "$deletedBranches" | xargs git branch -df
else
	LogSuccess "No deleted remote branches to clean locally"
fi
