#!/bin/bash
projectsFolder="/home/vlad-keylight/Src/subscription-suite-frontend2/projects";
libFolder="$projectsFolder/subscription-suite-lib/src/lib"
customerSubFolder="src/app"
tsConfigFileName="tsconfig.app.json"

pushd $projectsFolder > /dev/null

function scriptFailure() {
	# Print error in red
	echo -e "\e[31m$1\e[0m"
	popd > /dev/null
	exit 1
}

function checkSinglePath() {
	local path=$1
	local target=$2
	if [ -z "$path" ]; then
		scriptFailure "[$target] not found in [$PWD]"
	fi
	if (( $(echo "$path" | grep -c '') > 1 )); then
		scriptFailure "Found multiple entities:\n$path\nMust provide a unique name."
	fi
}

function addLineToFile() {
	local key=$1
	local line=$2
	local path=$3
	local cxName=$4
	local startingLine=$5
	if [ -z "$key" ] || [ -z "$key" ] || [ -z "$key" ] || [ -z "$cxName" ]; then
		echo "Invalid arguments provided for adding a line to file"
		return 1
	fi

	if [ ! -f "$path" ]; then
		echo "File [$path] not found"
		return 1
	fi

	fileName=$(basename $path)
	if [ -z "$(grep -F "$key" $path)" ]; then
		echo "Adding entry [$key] to [$fileName] for [$cxName]"
		if [ -n "$startingLine" ]; then
			# Add to the target line
			sed -i "$startingLine""i""$line" "$path"
		else
			# Add to the EOF
			echo "$line" >> "$path"
		fi
	else
		echo "Entry [$key] already present in [$fileName] for [$cxName]"
	fi
}

sourceEntity=$1
customerProjectName=$2

if [ -z "$sourceEntity" ] || [ -z "$customerProjectName" ]; then
	scriptFailure "\$1:SOURCE_ENTITY (file/directory) to override and \$2:CUSTOMER_PROJECT_NAME are required"
fi

customerFolder=$(find . -type d -name $customerProjectName)
checkSinglePath "$customerFolder"
customerName=$(basename "$customerFolder")

pushd $libFolder > /dev/null
entityPath=$(find . -name $sourceEntity | sed -E 's/^\.\///g')
popd > /dev/null

checkSinglePath "$entityPath"
entityName=$(basename "$entityPath")
srcPath="$libFolder/$entityPath"
destPath="$customerFolder/$customerSubFolder/$entityPath"
destDirectory=$(dirname "$destPath")
mkdir -p "$destDirectory"

# Copy directory/file from lib to the customer project
if [ -d "$srcPath" ]; then
	importPath="$entityPath/*"
    if [ -d "$destPath" ]; then
        "Directory [$entityName] already exists for [$customerName]"
	else                       
		echo "Copying directory [$entityName] for [$customerName]"
		cp -r $srcPath $destPath
	fi
else
	importPath="${entityPath%.*}"
    if [ ! -f "$srcPath" ]; then
        scriptFailure "Path [$srcPath] is not valid"
	fi

    if [ -s "$destPath" ]; then
        echo "File [$entityName] already exists for [$customerName]"
	else
		echo "Copying file [$entityName] for [$customerName]"
		cp $srcPath $destPath
	fi
	
	# Import base exports from .ts files only
	if [[ "$srcPath" == *.ts ]]; then
		suiteOrigImportPath="\"@suite-orig/$importPath\""
		importEntry="* as Lib"
		exportCount=$(egrep -c "^[ \t]*export[ \t]+" $srcPath)
		# If there is a single base export then process it accordingly
		if (( "$exportCount" == 1 )); then
			fullExport=$(sed -rn 's/^[ \t]*export[ \t]+(((class)|(interface)|(const)|(enum)|(function))[ \t]+)?([a-zA-Z0-9_-]+).*$/\2 \8/gp' $srcPath)
			exportType=$(echo "$fullExport" | cut -d' ' -f 1)
			exportName=$(echo "$fullExport" | cut -d' ' -f 2)

			if [ -z "$exportName" ] || [ -z "$exportType" ]; then
				echo "Unable to find appropriate export in [$entityName]"
			else
				echo "Found export [$exportName] of type [$exportType] in [$entityName]"
				libEntry="Lib${exportName^}"
				importEntry="{ $exportName as $libEntry }"
				if [ "$exportType" == "class" ] || [ "$exportType" == "interface" ]; then
					exportEntry="export $exportType $exportName extends $libEntry"
					addLineToFile "$exportEntry" "$exportEntry {}" "$destPath" "$customerName"
					
					# Check existence of overwritten modules file
					overwrittenModuleSearchDirectory=$destPath
					overwrittenModulePath=""
					while [ -n $overwrittenModuleSearchDirectory ] && [ -z $overwrittenModulePath ]
					do
						overwrittenModuleSearchDirectory=$(dirname $overwrittenModuleSearchDirectory)
						overwrittenModulePath=$(find $overwrittenModuleSearchDirectory -type f -name "overwritten*.ts" | head -1)
					done

					# Update overwritten modules file
					if [ -n "$overwrittenModulePath" ]; then
						importEntry="{ $exportName }"
						addLineToFile "$importEntry" "import $importEntry from $suiteOrigImportPath" "$overwrittenModulePath" "$customerName" 1
					fi
				fi
			fi
		else
			echo "Found $exportCount exports in [$entityName]"
		fi
		addLineToFile "$importEntry" "import $importEntry from $suiteOrigImportPath" "$destPath" "$customerName" 1
	fi
fi

# Update TS config file
suiteImportPath="\"@suite/$importPath\"";
addLineToFile "$suiteImportPath" "$suiteImportPath: [ \"$importPath\" ]," "$customerFolder/$tsConfigFileName" "$customerName"

# Return to starting folder
popd > /dev/null
