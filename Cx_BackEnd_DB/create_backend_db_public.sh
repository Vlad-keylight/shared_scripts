#!/bin/bash

expectedEnvFileName=".env";
sedKeyWordRegEx='\(\(TENANT_UUID\)\|\(TENANT\)\|\(MYSQL_NAME\)\)=';
grepKeyWordRegEx='((TENANT_UUID)|(TENANT)|(MYSQL_NAME))=';

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

if (( $# < 1 )); then
	echo "Missing arguments"
	echo "$0 \$1:CUSTOMER_NAME [\$2:ENV_CONFIG_PATH=$expectedEnvFileName] [\$3:SSH_TARGET \$4:SSH_TUNNEL_MYSQL_HOST \$5:SSH_TUNNEL_REDIRECT_PORT \$6:SSH_MYSQL_USER]"
	exit 1
fi

# Instructions for SandBox DB access: https://www.notion.so/keylight/Infrastructure-0068f50a574e4b5bbb5f2314ca73e125
tenantName=$1
envConfigFilePath=$2
if [ -z "$envConfigFilePath" ]; then
	envConfigFilePath=$expectedEnvFileName
fi

if [[ "$envConfigFilePath" != */"$expectedEnvFileName"  ]] && [[ "$envConfigFilePath" != "$expectedEnvFileName" ]]; then
	echo "Invalid config file path [$envConfigFilePath]."
	echo "Expected file name [$expectedEnvFileName]"
	exit 1
fi

if ! [ -f "$envConfigFilePath" ]; then
	echo "Config file not found @ [$envConfigFilePath]"
	echo "Please provid valid path."
	exit 1
fi

# tenantDb=$(echo $tenantName"_DB" | tr - _)
tenantDb=$tenantName

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 


if [ -z "$3" ] || [ -z "$4" ] || [ -z "$5" ] || [ -z "$6" ]; then
	echo "No SSH parameters provided. Skipping (re)creation of local DB [$tenantDb]"
else
	sqlDumpFolder=$(dirname "$0")/Dumps
	mkdir -p $sqlDumpFolder
	tenantSqlDumpFile=$sqlDumpFolder/"$tenantDb"_$(date +'%Y-%m-%d').sql

	if [ -f "$tenantSqlDumpFile" ] && [ -s "$tenantSqlDumpFile" ]; then
		echo "Cx DB [$tenantDb] already exported @ [$tenantSqlDumpFile]"
	else
		sshTarget=$3
		sshTunnelMySqlHost=$4
		sshTunnelRedirectPort=$5
		sshMySqlUser=$6
		
		# Setup SSH tunnel for querying SandBox DB
		# For it to work you have to add your private SSH key @ https://github.com/keylightberlin/key-people
		echo "Setting up SSH tunnel for SandBox DB access (exit the new terminal afterwards)"	
		gnome-terminal -- ssh -L $sshTunnelRedirectPort:$sshTunnelMySqlHost $sshTarget &
		# Export (dump) the requested Cx DB
		echo "Exporting SandBox DB [$tenantDb] to file [$tenantSqlDumpFile]..."	
		mysqldump $tenantDb -u $sshMySqlUser -p -h 127.0.0.1 -P $sshTunnelRedirectPort > $tenantSqlDumpFile || exit 1

		echo "Killing SSH tunnel process"
		pkill -f "ssh.*$sshTunnelMySqlHost"
	fi

	# sql_user=$(grep -oP "(?<=MYSQL_USER=).*" $envConfigFilePath)
	# sql_pass=$(grep -oP "(?<=MYSQL_PASS=).*" $envConfigFilePath)

	# (Re)creating tenant DB via MySQL commands
	sudo mysql -u root -e "drop database if exists \`$tenantDb\`; create database \`$tenantDb\`" || exit 1
	# Import the Cx DB locally
	echo "Importing [$tenantDb] DB from file [$tenantSqlDumpFile]"
	sudo mysql -u root $tenantDb < $tenantSqlDumpFile || exit 1
fi

tenantUUID=$(sudo mysql -u root $tenantDb -se 'select uuid from tenant limit 1')
if [ -z "$tenantUUID" ]; then
	echo "Tenant UUID not obtained from local DB [$tenantDb]"
	exit 1
fi

tenantCount=$(sudo mysql -u root $tenantDb -se 'select count(*) from tenant')
if (( $tenantCount != 1 )); then
	echo "Found $tenantCount tenants, using first UUID [$tenantUUID]"
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

echo "Adding [$tenantName] configuration @ line #$starting_line of [$envConfigFilePath]:"
# Input new tenant settings at the given position
for l in "${envTenantLinesToAdd[@]}"; do
	echo "    [$l]"
	envInput=$starting_line"i"$l
	sed -i "$envInput" "$envConfigFilePath"
done
