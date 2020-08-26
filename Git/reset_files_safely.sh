#!/bin/bash

currentScriptFolderName=$(dirname "$0")
currentScriptFileName=$(basename "$0")
# Include common helper functions
. "$currentScriptFolderName/_git_common.sh" --source-only

entitySubPath=$1

# Get current git branch
gitInitialBranch=$(git rev-parse --abbrev-ref HEAD)
if [ -z "$gitInitialBranch" ]
then
	ScriptFailure "Unable to get the current git branch"
fi

diffFiles=$(git diff origin/master --name-only)
diffFilesCount=$(echo "$diffFiles" | grep -c '')
if (( "$diffFilesCount" == 0 )) || [ -z "$diffFiles" ]; then
	LogSuccess "No diff files found on branch [$gitInitialBranch]"
	exit 0
fi

LogWarning "Found $diffFilesCount diff files on branch [$gitInitialBranch]\n"
count=0
for diffFile in $diffFiles
do
	count=$((count+1))
	LogInfo "File #$count/$diffFilesCount @ [$diffFile]"
	if [ -n "$entitySubPath" ] &&
		[[ $diffFile != $entitySubPath ]] &&
		[[ $diffFile != */$entitySubPath ]] &&
		[[ $diffFile != $entitySubPath/* ]] &&
		[[ $diffFile != */$entitySubPath/* ]]; then
		LogInfo "\tnot matching path pattern [$entitySubPath]"
		continue
	fi

	fileName=$(basename "$diffFile")
	if [ -n "$(ConfirmAction Reset file \#$count/$diffFilesCount [$fileName])" ]; then
		RunGitCommandSafely "git checkout origin/master -- \"$diffFile\" || git rm \"$diffFile\""
		LogSuccess "\tReset file [$fileName]"
	else
		LogInfo "\tSkipping reset of file [$fileName]"
	fi
	echo ""
done
