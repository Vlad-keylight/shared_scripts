#!/bin/bash

projectsFolder="/home/vlad-keylight/Src/subscription-suite-frontend2/projects";
libFolder="$projectsFolder/subscription-suite-lib/src/lib"
customerSubFolder="src/app"
tsConfigFileName="tsconfig.app.json"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

# Include common helper functions
. $(dirname "$0")/../_common.sh --source-only

pushd $projectsFolder > /dev/null

function scriptFailure() {
	popd > /dev/null
	ScriptFailure "$@"
}

function findEntity() {
	local target=$1
	local type=$2
	local searchDirectory=$3
	local searchCommand="find"
	if [ -z "$target" ]; then
		echo ""
		return 1
	fi
	
	if [ -z "$searchDirectory" ] || [ "$searchDirectory" == "." ]; then
		searchCommand="$searchCommand ."
	else
		searchCommand="$searchCommand \"$searchDirectory\""
	fi
	if [ -n "$type" ]; then
		searchCommand="$searchCommand -type $type"
	fi
	if [[ "$target" == */* ]]; then
		searchCommand="$searchCommand -ipath \"*/$target\""
	else
		searchCommand="$searchCommand -iname \"$target\""
	fi
	eval "$searchCommand"
}

function findEntityRelativePath() {
	local searchFolder=$1
	local searchEntity=$2
	# Force output of a relative path from the search folder
	pushd "$searchFolder" > /dev/null
	local entityPath=$(findEntity "$searchEntity" | sed -E 's/^\.\///g')
	popd > /dev/null
	echo "$entityPath"
}

function checkSinglePath() {
	local entityDetail=$1
	local path=$2
	local target=$3
	local searchDirectory=$4
	if [ -z "$path" ]; then
		scriptFailure "${entityDetail^} [$target] not found in [$searchDirectory]"
	fi
	if (( $(echo "$path" | grep -c '') > 1 )); then
		scriptFailure "Found multiple $entityDetail""s:\n$path\nin [$searchDirectory]\nMust provide a unique name."
	fi
}

function addLineToFile() {
	local key=$1
	local line=$2
	local path=$3
	local cxName=$4
	local lineStartSearchRegex=$5
	local defaultStartingLine=$6
	if [ -z "$key" ] || [ -z "$key" ] || [ -z "$key" ] || [ -z "$cxName" ]; then
		LogWarning "Invalid arguments provided for adding a line to file"
		return 1
	fi

	if [ ! -f "$path" ]; then
		LogWarning "File [$path] not found"
		return 1
	fi

	local startingLine=$defaultStartingLine
	if [ -n "$lineStartSearchRegex" ]; then
		local grepResultLine=$(egrep "^[ \t]*$lineStartSearchRegex" "$path" -n | tail -1 | egrep "^[0-9]+" -o)
		if [ -n "$grepResultLine" ]; then
			startingLine=$grepResultLine
		fi
	fi

	fileName=$(basename $path)
	if [ -z "$(grep -F "$key" $path)" ]; then
		local message="Adding entry [$key]\n\tto [$fileName]\n\tfor [$cxName]"
		if [ -n "$startingLine" ] && (( "$startingLine" >= 0 )); then
			startingLine=$((startingLine+1))
			LogSuccess "$message @ line $startingLine"
			# Add to the target line
			sed -i "$startingLine""i""$line" "$path"
		else
			# Add to the EOF
			LogSuccess "$message @ EOF"
			echo "$line" >> "$path"
		fi
	else
		LogWarning "Entry [$key]\n\talready present in [$fileName]\n\tfor [$cxName]"
	fi
}

function findOverwrittenModulePath() {
	local searchDirectory="$1"
	local path=""
	while [ -n $searchDirectory ] && [ -z $path ]; do
		searchDirectory=$(dirname $searchDirectory)
		# If there are multiple modules take the first one
		path=$(findEntity "overwritten*.ts" "f" "$searchDirectory" | head -1)
	done
	echo "$path"
}

sourceEntity=$1
customerProjectName=$2

if [ -z "$sourceEntity" ] || [ -z "$customerProjectName" ]; then
	scriptFailure "\$1:SOURCE_ENTITY (file/directory) to override and \$2:CUSTOMER_PROJECT_NAME are required"
fi

customerFolder=$(findEntity "$customerProjectName" "d")
checkSinglePath "customer folder" "$customerFolder" "$customerProjectName" "$PWD"
customerName=$(basename "$customerFolder")

# Force output of a relative path from the lib folder
entityPath=$(findEntityRelativePath "$libFolder" "$sourceEntity")
checkSinglePath "entity" "$entityPath" "$sourceEntity" "$libFolder"
entityName=$(basename "$entityPath")
srcPath="$libFolder/$entityPath"
destPath="$customerFolder/$customerSubFolder/$entityPath"
# Create destination directory, if it is not already present
mkdir -p "$(dirname "$destPath")"

# Check existence of overwritten modules file
overwrittenModulePath=$(findOverwrittenModulePath "$destPath")
if [ -n "$overwrittenModulePath" ]; then
	# Switch to absolute path
	overwrittenModulePath=$(realpath "$overwrittenModulePath")
	LogSuccess "Overwritten module found @ [$overwrittenModulePath]"
fi

# Copy directory/file from lib to the customer project
if [ -d "$srcPath" ]; then
	tsConfigImportPath="$entityPath/*"
	if [ -d "$destPath" ]; then
		LogWarning "Directory [$entityName] already exists for [$customerName]\n"
		find "$srcPath" -maxdepth 1 -type f -exec bash -c "CopyFileSafely \"{}\" \"$destPath\"" \;

		subDirectories=$(find "$srcPath" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | sed 's/^/ - /g')
		if [ -n "$subDirectories" ]; then
			LogWarning "Skipping additional subdirectories\n$subDirectories"
		fi
		echo ""
	else
		LogSuccess "Copying directory [$entityName] for [$customerName]"
		cp -r "$srcPath" "$destPath"
	fi
else
	# Remove the file extension e.g. "my.component.ts" -> "my.component"
	fileImportPath="${entityPath%.*}"
	tsConfigImportPath="$fileImportPath"

	if [ ! -f "$srcPath" ]; then
		scriptFailure "Path [$srcPath] is not valid"
	fi

	CopyFileSafely "$srcPath" $(dirname "$destPath");

	# Import base exports from .ts files only
	if [[ "$srcPath" == *.ts ]]; then
		suiteOrigImportPath="\"@suite-orig/$fileImportPath\""
		destImportEntry="* as Lib"
		exportCount=$(egrep -c "^[ \t]*export[ \t]+" $srcPath)
		# If there is a single base export then process it accordingly
		if (( "$exportCount" == 1 )); then
			fullExport=$(sed -rn 's/^[ \t]*export[ \t]+(((class)|(interface)|(const)|(enum)|(function))[ \t]+)?([a-zA-Z0-9_-]+).*$/\2 \8/gp' $srcPath)
			exportType=$(echo "$fullExport" | cut -d' ' -f 1)
			exportName=$(echo "$fullExport" | cut -d' ' -f 2)

			if [ -z "$exportName" ] || [ -z "$exportType" ]; then
				LogWarning "Unable to find appropriate export in [$entityName]"
			else
				LogInfo "Found export [$exportName] of type [$exportType] in [$entityName]"
				libEntry="Lib${exportName^}"
				destImportEntry="{ $exportName as $libEntry }"
				if [ "$exportType" == "class" ] || [ "$exportType" == "interface" ]; then
					exportEntry="export $exportType $exportName extends $libEntry"
					# Add line after the matched line or to the end of file
					addLineToFile "$exportEntry" "$exportEntry {" "$destPath" "$customerName" "export\s"

					# Update overwritten modules file
					if [ -n "$overwrittenModulePath" ]; then
						# Add line after the matched line or to the end of file
						addLineToFile "$exportName" "$exportName," \
							"$overwrittenModulePath" "$customerName" \
							"declarations:"
						omImportEntry="{ $exportName }"
						# Add line after the matched line or to the start of file
						addLineToFile "$omImportEntry" "import $omImportEntry from $suiteOrigImportPath" \
							"$overwrittenModulePath" "$customerName" \
							"import\s" 0
					fi
				fi
			fi
		else
			LogInfo "Found $exportCount exports in [$entityName]"
		fi
		# Add line after the matched line or to the start of file
		addLineToFile "$destImportEntry" "import $destImportEntry from $suiteOrigImportPath" \
			"$destPath" "$customerName" \
			"import\s.*(\"@suite-orig/)?" 0
	fi
fi

# Update TS config file
suiteImportPath="\"@suite/$tsConfigImportPath\"";
tsConfigFilePath="$customerFolder/$tsConfigFileName";
# Add line to the last @suite path or at the end of file
addLineToFile "$suiteImportPath" "$suiteImportPath: [ \"$tsConfigImportPath\" ]," \
	"$tsConfigFilePath" "$customerName" \
	"\"@suite/"

if [ -d "$srcPath" ]; then
	echo ""
	tsFilePattern="$entityName.*.ts"
	relatedTsFile=$(findEntityRelativePath "$srcPath" "$tsFilePattern" | egrep -v "spec.ts$")
	if [ -n "$relatedTsFile" ]; then
		# Prefix with directory path
		relatedTsFile="$entityPath/$relatedTsFile"
		relatedTsFileName=$(basename "$relatedTsFile")
		checkSinglePath "related .ts file" "$relatedTsFile" "$tsFilePattern" "$srcPath"

		if [ -n "$(ConfirmAction Update related .ts file [$relatedTsFileName])" ]; then
			$0 "$relatedTsFile" "$customerProjectName"
		fi
	else
		LogWarning "Related .ts file not found for [$entityName]"
	fi
fi

# Return to starting folder
popd > /dev/null
