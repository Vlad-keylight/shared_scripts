currentScriptFolderName=$(dirname "$0")
# Include common helper functions
. "$currentScriptFolderName/_git_common.sh" --source-only

gitCurrentBranch=$(GetCurrentBranchName)
LogSuccess "Current Git branch [$gitCurrentBranch]"
rebasedBranchName="${gitCurrentBranch}-rebased"
if [ -n "$(ConfirmAction Rebase to new branch [$rebasedBranchName] and push from it)" ]; then
    RunGitCommandSafely "git checkout -b $rebasedBranchName"
    RunGitCommandSafely "git push -u origin $rebasedBranchName"
fi
