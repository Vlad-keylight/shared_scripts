#!/bin/bash

expectedEnvFileName=".env";

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

if (( $# < 6 )); then
  echo "Missing arguments"
  echo "$0 SSH_TUNNEL_MYSQL_HOST SSH_TUNNEL_REDIRECT_PORT SSH_MYSQL_USER SSH_TARGET ENV_CONFIG_PATH CUSTOMER_NAME" 
  exit 1
fi

# Instructions for SandBox DB access: https://www.notion.so/keylight/Infrastructure-0068f50a574e4b5bbb5f2314ca73e125
sshTunnelMySqlHost=$1
sshTunnelRedirectPort=$2
sshMySqlUser=$3
sshTarget=$4
envConfigFilePath=$5
tenantName=$6

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

sedKeyWordRegEx='\(\(TENANT_UUID\)\|\(TENANT\)\|\(MYSQL_NAME\)\)=';
grepKeyWordRegEx='((TENANT_UUID)|(TENANT)|(MYSQL_NAME))=';
envTenantLinesToCheck=( "TENANT=$tenantName" "MYSQL_NAME=$tenantDb" )

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

for l in "${envTenantLinesToCheck[@]}"; do
	existing_tenant_field=$(egrep $l"$" $envConfigFilePath)
	if [ "$existing_tenant_field" != "" ]; then
		echo "Found existing tenant field [$existing_tenant_field]"
		echo "in [$envConfigFilePath]"
		echo "Please remove related config fields for customer [$tenantName]"
		exit 1
	fi
done

sqlDumpFolder=$(dirname "$0")/Dumps
mkdir -p $sqlDumpFolder
tenantSqlDumpFile=$sqlDumpFolder/"$tenantDb"_$(date +'%Y-%m-%d').sql

if [ -f "$tenantSqlDumpFile" ] && [ -s "$tenantSqlDumpFile" ]; then
    echo "Cx DB [$tenantDb] already exported @ [$tenantSqlDumpFile]"
else
	# Setup SSH tunnel for querying SandBox DB
	# For it to work you have to add your private SSH key @ https://github.com/keylightberlin/key-people
	echo "Setting up SSH tunnel for SandBox DB access (exit the new terminal afterwards)"	
	gnome-terminal -- ssh -L $sshTunnelRedirectPort:$sshTunnelMySqlHost $sshTarget &
	# Export (dump) the requested Cx DB
	echo "Exporting SandBox DB [$tenantDb] to file [$tenantSqlDumpFile]..."	
	mysqldump $tenantDb -u $sshMySqlUser -p -h 127.0.0.1 -P $sshTunnelRedirectPort > $tenantSqlDumpFile || exit 1
fi

# sql_user=$(grep -oP "(?<=MYSQL_USER=).*" $envConfigFilePath)
# sql_pass=$(grep -oP "(?<=MYSQL_PASS=).*" $envConfigFilePath)

# (Re)creating tenant DB via MySQL commands
sudo mysql -u root -e "drop database if exists \`$tenantDb\`; create database \`$tenantDb\`" || exit 1
# Import the Cx DB locally
echo "Importing [$tenantDb] DB from file [$tenantSqlDumpFile]"
sudo mysql -u root $tenantDb < $tenantSqlDumpFile || exit 1
tenantUUID=$(sudo mysql -u root $tenantDb -se 'select uuid from tenant limit 1')
if [ "$tenantUUID" == "" ]; then
  echo "Tenant UUID not obtained from local DB [$tenantDb]"
  exit 1
fi

envTenantLinesToAdd=( "TENANT_UUID=$tenantUUID" "${envTenantLinesToCheck[@]}" )

# Comment out existing tenant settings, create a .bak backup file.
sed -i.bak 's/\(^'$sedKeyWordRegEx'\)/#\ \1/' "$envConfigFilePath"

# Find a starting line for tenant settings to insert the new tenant settings at that position.
# Otherwise fallback to the start of file.
starting_line=$(egrep "^[# \t]*"$grepKeyWordRegEx "$envConfigFilePath" -n -m 1 | egrep "^[0-9]+" -o)
if [ "$starting_line" = "" ]; then
	starting_line=1
fi

echo "Adding [$tenantName] configuration @ line #$starting_line of [$envConfigFilePath]:"
# Input new line at the given position
envInput=$starting_line"i"'\\'
sed -i $envInput "$envConfigFilePath"
# Input new tenant settings at the given position
for l in "${envTenantLinesToAdd[@]}"; do
	echo "    [$l]"
	envInput=$starting_line"i"$l
	sed -i "$envInput" "$envConfigFilePath"
done

echo "Killing SSH tunnel process"
pkill -f "ssh.*$sshTunnelMySqlHost"
