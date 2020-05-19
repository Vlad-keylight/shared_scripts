#!/bin/bash
projectsFolder="/home/vlad-keylight/Src/subscription-suite-frontend2/projects";
libFolder="$projectsFolder/subscription-suite-lib/src/lib"
customerSubFolder="src/app"
tsConfigFileName="tsconfig.app.json"

pushd $projectsFolder > /dev/null

scriptFailure() {
	echo $1
	popd > /dev/null
	exit 1
}

addLineToFile() {
	local key=$1
	local line=$2
	local path=$3
	if [ -z "$key" ] || [ -z "$key" ] || [ -z "$key" ]; then
		echo "Invalid arguments provided for adding a line to file"
		return 1
	fi

	if [ ! -f "$path" ]; then
		echo "File [$path] not found in [$projectsFolder]"
		return 1
	fi

	if [ -z "$(grep -F "$key" $path)" ]; then
		echo "Adding \"$key\" to [$path]"
		echo "$line" >> "$path"
	else
		echo "\"$key\" already present in [$path]"
	fi
}

sourceEntity=$1
customerProjectName=$2

if [ -z "$sourceEntity" ] || [ -z "$customerProjectName" ]; then
	scriptFailure "\$1:SOURCE_ENTITY (file/directory) to override and \$2:CUSTOMER_PROJECT_NAME are required"
fi

customerFolder=$(find . -type d -name $customerProjectName)
if [ -z "$customerFolder" ]; then
	scriptFailure "Customer folder [$customerProjectName] not found in [$projectsFolder]"
fi
if (( $(echo $customerFolder | grep -c '') > 1 )); then
	scriptFailure "Must provide a unique name. Found multiple folders: [$customerFolder]"
fi

pushd $libFolder > /dev/null
entityPath=$(find . -name $sourceEntity | sed -E 's/^\.\///g')
popd > /dev/null
if [ -z "$entityPath" ]; then
	scriptFailure "Entity [$sourceEntity] not found in [$libFolder]"
fi
if (( $(echo $entityPath | grep -c '') > 1 )); then
	scriptFailure "Must provide a unique name. Found multiple entities: [$entityPath]"
fi

srcPath=$libFolder/$entityPath
destPath=$customerFolder/$customerSubFolder/$entityPath
destDirectory=$(dirname "$destPath")
mkdir -p $destDirectory

# Copy directory/file from lib to the customer project
if [ -d "$srcPath" ]; then
	importPath="$entityPath/*"
    if [ -d "$destPath" ]; then
        "Directory [$destPath] already exists"
	else                       
		echo "Copying directory [$srcPath]"
		cp -r $srcPath $destPath
	fi
else
	importPath="${entityPath%.*}"
    if [ ! -f "$srcPath" ]; then
        scriptFailure "Path [$srcPath] is not valid"
	fi

    if [ -s "$destPath" ]; then
        echo "File [$destPath] already exists"
	else
		echo "Copying file [$srcPath]"
		cp $srcPath $destPath
	fi
	
	# Import base exports from .ts files only
	if [[ "$srcPath" == *.ts ]]; then
		suiteOrigImportPath="\"@suite-orig/$importPath\""
		importEntry="* as Lib"
		exportCount=$(egrep -c "^[ \t]*export[ \t]+" $srcPath)
		# If there is a single base export then process it accordingly
		if (( "$exportCount" == 1 )); then
			fullExport=$(sed -rn 's/^[ \t]*export[ \t]+(((class)|(interface))[ \t]+)?([a-zA-Z0-9_-]+).*$/\2 \5/gp' $srcPath)
			exportType=$(echo "$fullExport" | cut -d' ' -f 1)
			exportName=$(echo "$fullExport" | cut -d' ' -f 2)

			if [ -z "$exportName" ] || [ -z "$exportType" ]; then
				echo "Unable to find appropriate exports in [$srcPath]"
			else
				echo "Found export [$exportName] of type [$exportType]"
				libEntry="Lib${exportName^}"
				exportEntry="export $exportType $exportName extends $libEntry"
				addLineToFile "$exportEntry" "$exportEntry {}" "$destPath"
				importEntry="{ $exportName as $libEntry }"
			fi

			addLineToFile "$importEntry" "import $importEntry from $suiteOrigImportPath" "$destPath"

			if [ -n "$exportName" ]; then
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
					addLineToFile "$importEntry" "import $importEntry from $suiteOrigImportPath" "$overwrittenModulePath"
				fi
			fi
		fi
	fi
fi

# Update TS config file
suiteImportPath="\"@suite/$importPath\"";
addLineToFile "$suiteImportPath" "$suiteImportPath: [ \"$importPath\" ]," "$tsConfigPath"

# Return to starting folder
popd > /dev/null
