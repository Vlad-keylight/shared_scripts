#!/bin/bash

expectedEnvFileName=".env";
sedKeyWordRegEx='\(\(TENANT_UUID\)\|\(TENANT\)\|\(MYSQL_NAME\)\)=';
grepKeyWordRegEx='((TENANT_UUID)|(TENANT)|(MYSQL_NAME))=';

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

currentScriptFolderName=$(dirname "$0")
currentScriptFileName=$(basename "$0")
# Include common helper functions
. "$currentScriptFolderName/../_common.sh" --source-only

if (( $# < 1 )); then
	ScriptFailure "Missing arguments\n$currentScriptFileName \$1:CUSTOMER_NAME [\$2:ENV_CONFIG_PATH=$expectedEnvFileName] [\$3:SSH_TARGET \$4:SSH_TUNNEL_MYSQL_HOST \$5:SSH_TUNNEL_REDIRECT_PORT \$6:SSH_MYSQL_USER]"
fi

function mySqlExecQuery() {
	if [ -n "$2" ]; then
		sudo mysql -u root --database="$2" -se "$1"
	else
		sudo mysql -u root -se "$1"
	fi
}
function mySqlImportDb() {
	LogSuccess "Importing [$1] DB from file [$2]"
	sudo mysql -u root "$1" < "$2" || ScriptFailure "mySQL import DB failed"
}
function mySqlRecreateDb() {
	LogSuccess "Recreating local [$1] DB"
	mySqlExecQuery "drop database if exists \`$1\`; create database \`$1\`"
}

tenantName=$1
envConfigFilePath=$2
if [ -z "$envConfigFilePath" ]; then
	envConfigFilePath=$expectedEnvFileName
fi

if [[ "$envConfigFilePath" != */"$expectedEnvFileName"  ]] && [[ "$envConfigFilePath" != "$expectedEnvFileName" ]]; then
	ScriptFailure "Invalid config file path [$envConfigFilePath].\nExpected file name [$expectedEnvFileName]"
fi

if ! [ -f "$envConfigFilePath" ]; then
	ScriptFailure "Config file not found @ [$envConfigFilePath]\nPlease provid valid path."
fi

# tenantDb=$(echo $tenantName"_DB" | tr - _)
tenantDb=$tenantName

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

LogWarning "How-to for SandBox DB access @ https://www.notion.so/keylight/Infrastructure-0068f50a574e4b5bbb5f2314ca73e125"

if [ -z "$3" ] || [ -z "$4" ] || [ -z "$5" ] || [ -z "$6" ]; then
	LogWarning "No SSH parameters provided. Skipping (re)creation of local DB [$tenantDb]"
else
	sqlDumpFolder="$currentScriptFolderName/Dumps"
	mkdir -p "$sqlDumpFolder"
	tenantSqlDumpFile="$sqlDumpFolder/${tenantDb}_$(date +'%Y-%m-%d').sql"

	if [ -f "$tenantSqlDumpFile" ] && [ -s "$tenantSqlDumpFile" ]; then
		LogWarning "Cx DB [$tenantDb] already exported @ [$tenantSqlDumpFile]"
	else
		sshTarget=$3
		sshTunnelMySqlHost=$4
		sshTunnelRedirectPort=$5
		sshMySqlUser=$6
		
		# Setup SSH tunnel for querying SandBox DB
		LogSuccess "Setting up SSH tunnel for SandBox DB access (exit the new terminal afterwards) via local private key"
		LogWarning "Make sure to have your public key @ https://github.com/keylightberlin/key-people"
		gnome-terminal -- ssh -L $sshTunnelRedirectPort:$sshTunnelMySqlHost $sshTarget &
		# Export (dump) the requested Cx DB
		LogSuccess "Exporting SandBox DB [$tenantDb]\n\tto file [$tenantSqlDumpFile]..."
		LogWarning "MySQL user (over SSH): [$sshMySqlUser]"
		mysqldump $tenantDb -u $sshMySqlUser -p -h 127.0.0.1 -P $sshTunnelRedirectPort > $tenantSqlDumpFile || exit 1

		LogWarning "Killing SSH tunnel process"
		pkill -f "ssh.*$sshTunnelMySqlHost"
	fi

	# sql_user=$(grep -oP "(?<=MYSQL_USER=).*" $envConfigFilePath)
	# sql_pass=$(grep -oP "(?<=MYSQL_PASS=).*" $envConfigFilePath)

	# (Re)creating tenant DB via MySQL commands
	mySqlRecreateDb "$tenantDb"
	# Import the Cx DB locally
	mySqlImportDb "$tenantDb" "$tenantSqlDumpFile"
fi

tenantUUID=$(mySqlExecQuery 'select uuid from tenant limit 1' "$tenantDb")
if [ -z "$tenantUUID" ]; then
	ScriptFailure "Tenant UUID not obtained from local DB [$tenantDb]"
fi

tenantCount=$(mySqlExecQuery "select count(*) from tenant" "$tenantDb")
if (( $tenantCount != 1 )); then
	LogWarning "Found $tenantCount tenants, using first UUID [$tenantUUID]"
fi

envTenantLinesToAdd=( "TENANT_UUID=$tenantUUID" "TENANT=$tenantName" "MYSQL_NAME=$tenantDb" )

# Find a starting line for tenant settings to insert the new tenant settings at that position.
# Otherwise fallback to the start of file.
starting_line=$(egrep "^[# \t]*"$grepKeyWordRegEx "$envConfigFilePath" -n -m 1 | egrep "^[0-9]+" -o)
if [ "$starting_line" = "" ]; then
	starting_line=1
fi

# Remove existing tenant settings, create a .bak backup file.
sed -i.bak '/^[# \t]*'$sedKeyWordRegEx'/d' "$envConfigFilePath"

LogSuccess "Adding [$tenantName] configuration @ line #$starting_line of [$envConfigFilePath]:"
# Input new tenant settings at the given position
for l in "${envTenantLinesToAdd[@]}"; do
	LogSuccess "\t[$l]"
	envInput=$starting_line"i"$l
	sed -i "$envInput" "$envConfigFilePath"
done
