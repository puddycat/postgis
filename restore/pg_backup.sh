#! /usr/bin/env bash
#
# postgis/bin/build
#
# raymondstrose@hotmail.com
#
#   Build a Postgres base image.
#

append () { sed -e "s?\$?$@?"; }
prepend () { sed -e "s?^?$@?"; }
indent () { { if [ $# -ne 0 ]; then echo -e "$@"; else cat; fi; } | prepend "    "; }
error () { { if [ $# -ne 0 ]; then echo -e "$@"; else cat; fi; } | prepend "$PROGNAME: error: " >&2; }
warning () { { if [ $# -ne 0 ]; then echo -e "$@"; else cat; fi; } | prepend "$PROGNAME: warning: " >&2; }
notice () { { if [ $# -ne 0 ]; then echo -e "$@"; else cat; fi; } | prepend "$PROGNAME: notice: " >&2; }
info () { { if [ $# -ne 0 ]; then echo -e "$@"; else cat; fi; } | prepend "$PROGNAME: info: " >&2; }
verbose () { $VERBOSE_MODE && { { if [ $# -ne 0 ]; then echo -e "$@"; else cat; fi; } | prepend "$PROGNAME: verbose: " >&2; } }
debug () { $DEBUG_MODE && { { if [ $# -ne 0 ]; then echo -e "$@"; else cat; fi; } | prepend "$PROGNAME: debug: " >&2; } }

function execute ()
{
    declare -a params;

    for param; do
        if [[ -z "${param}" || "${param}" =~ [^A-Za-z0-9_@%+=:,./-] ]]; then
            params+=("'${param//\'/\'\"\'\"\'}'");
        else
            params+=("${param}");
        fi;
    done;

    debug "${params[*]}";
    eval ${params[*]};
}

main ()
{
# Display usage information.
#
    usage ()
    {
        cat <<-EOF >&2
			$PROGNAME: usage: $PROGNAME [--help] [--debug] [--verbose] [--noop] [--config-dir {path}] [--docker-host {spec}] [--docker-context {name}]

            --docker-context {name}     Specify the Docker context for the build (default: $BUILD_DOCKER_CONTEXT)
            --docker-host {spec}        Specify the Docker host as per https://docs.docker.com/engine/security/protect-access/ (default $DOCKER_HOST)
			--config-dir {path}         Specify the configuration directory (default: $CONFIG_DIR)
			--noop                      Don't perform the operation, just report the actions that would be carried out.
			--verbose                   Enable verbose mode.
			--debug                     Enable debug mode.
			--help                      Display this usage information.
			EOF

        return 0;
    }

# Load configuration files.
#
	load_config ()
	{
		if [ "$CONFIG_DIR" ]; then
			if [ -d "$CONFIG_DIR" ]; then

			# Configure the process
			#
				notice "Loading configuration.";
				for filename in $CONFIG_DIR/*; do
					indent "$filename" | debug;
					[ -f "$filename" ] && { source "$filename" || return 1; }
				done;
			fi;
		fi;

		return 0;
	}

	export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/go/bin";
    export PROGNAME=`basename "$0"`;
    export PROGDIR=`dirname "$0"`;
    export INSTALL_DIR=`dirname "$PROGDIR"`;
    export CONFIG_DIR="$INSTALL_DIR/etc/$PROGNAME";
    export LIB_DIR="$INSTALL_DIR/lib/$PROGNAME";
    export WORK_DIR="$INSTALL_DIR/var/$PROGNAME";
    export DEBUG_MODE=false;
    export VERBOSE_MODE=false;
    export NOOP_MODE=false;
    #export DOCKER_HOST="ssh://raymond@localhost";
    #export DOCKER_HOST="";
    export BUILD_DOCKER_CONTEXT="";
	export IMAGE_PREFIX="raymondstrose/";
	export IMAGE_NAME="postgis";
	export IMAGE_TAG="13.1";

# Load the default configuration files.
	load_config || return $?;

    while [ $# -gt 0 ]; do
        case "$1" in
		-c)
			if [ -r "$2" ]; then
				source "$2";
				shift;
			else
				error "Unreadable config file \"$2\"";
				exit 1;
			fi;;
        --docker-context|--docker-context=?*)
            case "$1" in
            --docker-context)		BUILD_DOCKER_CONTEXT="$2"; shift;;
            --docker-context=?*)	BUILD_DOCKER_CONTEXT="${1#--docker-context=}";;
            esac;;
        --image-name|--image-name=?*)
            case "$1" in
            --image-name)		IMAGE_NAME="$2"; shift;;
            --image-name=?*)	IMAGE_NAME="${1#--image-name=}";;
            esac;;
        --image-tag|--image-tag=?*)
            case "$1" in
            --image-tag)	IMAGE_TAG="$2"; shift;;
            --image-tag=?*)	IMAGE_TAG="${1#--image-tag=}";;
            esac;;
        --docker-host|--docker-host=?*)
            case "$1" in
            --docker-host)		DOCKER_HOST="$2"; shift;;
            --docker-host=?*)	DOCKER_HOST="${1#--docker-host=}";;
            esac;;
        --config-dir|--config-dir=?*)
            case "$1" in
            --config-dir)		CONFIG_DIR="$2"; shift;;
            --config-dir=?*)	CONFIG_DIR="${1#--config-dir=}";;
            esac;

		# Load the specified configuration files.
			load_config || return $?;;
        --debug)	$DEBUG_MODE && set -x; DEBUG_MODE=true;;
        --noop)		NOOP_MODE=true;;
        --verbose)	VERBOSE_MODE=true;;
        --help) usage; return 2;;
        --) shift; break;;
        -*)	error "unknown option \"$1\""; usage; return 1;;
        *)	error "unrecognised command line argument \"$1\""; usage; return 1;;
        esac;

        shift;
    done;

###########################
####### LOAD CONFIG #######
###########################

	if [ $# = 0 ]; then
		SCRIPTPATH=$(cd ${0%/*} && pwd -P)
		source $SCRIPTPATH/pg_backup.config
	fi;

	debug `uname -a`;
	debug "$(env) | awk '/PASSWORD.*/ FS== { printf("%s=xxxxxxxx", $1); }'";

###########################
#### PRE-BACKUP CHECKS ####
###########################

# Make sure we're running as the required backup user
	if [ "$BACKUP_USER" != "" -a "$(id -un)" != "$BACKUP_USER" ]; then
		error "This script must be run as $BACKUP_USER. Exiting.";
		exit 1;
	fi;

###########################
### INITIALISE DEFAULTS ###
###########################

	if [ ! "$HOSTNAME" ]; then
		if [ "$PGHOST" ]; then
			HOSTNAME="$PGHOST";
		else
			HOSTNAME="localhost";
		fi;
	fi;

#	if [ "$POSTGRESQL_SERVICE_HOST" ]; then
#		HOSTNAME="$POSTGRESQL_SERVICE_HOST";
#	fi;

	if [ ! "$PGUSER" ]; then
		PGUSER="postgis";
	fi;

#	PASSWORD=`execute kubectl get secret --namespace postgis postgresql-backup -o yaml | jq '.data'`;
#
#	if [ $? -ne 0 ]; then
#		error "failed to retrieve password";
#		exit 1;
#	fi;

	execute echo "$HOSTNAME:$POSTGRESQL_HA_POSTGRESQL_SERVICE_PORT_POSTGRESQL:template1:$PGUSER:$POSTGRES_PASSWORD" >>$HOME/.pgpass;
	execute echo "$HOSTNAME:$POSTGRESQL_HA_POSTGRESQL_SERVICE_PORT_POSTGRESQL:postgis:$PGUSER:$POSTGRES_PASSWORD" >>$HOME/.pgpass;
	execute echo "$HOSTNAME:$POSTGRESQL_HA_POSTGRESQL_SERVICE_PORT_POSTGRESQL:repmgr:$PGUSER:$POSTGRES_PASSWORD" >>$HOME/.pgpass;
	execute chmod 600 $HOME/.pgpass;

###########################
#### START THE BACKUPS ####
###########################

	FINAL_BACKUP_DIR=$BACKUP_DIR"`date +\%Y-\%m-\%d`/";

	debug "Making backup directory in $FINAL_BACKUP_DIR";

	if ! execute mkdir -p $FINAL_BACKUP_DIR; then
		error "Cannot create backup directory in $FINAL_BACKUP_DIR. Go and fix it!";
		exit 1;
	fi;

#######################
### GLOBALS BACKUPS ###
#######################

	echo -e "\n\nPerforming globals backup";
	echo -e "--------------------------------------------\n";

	if [ $ENABLE_GLOBALS_BACKUPS = "yes" ]
	then
		echo "Globals backup";

		set -o pipefail;
		if ! execute pg_dumpall -g -h "$HOSTNAME" -U "$PGUSER" | gzip >$FINAL_BACKUP_DIR"globals".sql.gz.in_progress; then
			error "Failed to produce globals backup";
		else
			mv $FINAL_BACKUP_DIR"globals".sql.gz.in_progress $FINAL_BACKUP_DIR"globals".sql.gz;
		fi;
		set +o pipefail;
	else
		echo "None";
	fi;

###########################
### SCHEMA-ONLY BACKUPS ###
###########################

	for SCHEMA_ONLY_DB in ${SCHEMA_ONLY_LIST//,/ }
	do
		SCHEMA_ONLY_CLAUSE="$SCHEMA_ONLY_CLAUSE or datname ~ '$SCHEMA_ONLY_DB'";
	done;

	SCHEMA_ONLY_QUERY="select datname from pg_database where false $SCHEMA_ONLY_CLAUSE order by datname;";

	echo -e "\n\nPerforming schema-only backups";
	echo -e "--------------------------------------------\n";

	SCHEMA_ONLY_DB_LIST=`execute psql -h "$HOSTNAME" -U "$PGUSER" -At -c "$SCHEMA_ONLY_QUERY" postgis`;

	echo -e "The following databases were matched for schema-only backup:\n${SCHEMA_ONLY_DB_LIST}\n";

	for DATABASE in $SCHEMA_ONLY_DB_LIST; do
		echo "Schema-only backup of $DATABASE";

		echo "$HOSTNAME:$POSTGRESQL_HA_POSTGRESQL_SERVICE_PORT_POSTGRESQL:$DATABASE:$PGUSER:$POSTGRES_PASSWORD" >>$HOME/.pgpass;

		set -o pipefail;
		if ! execute pg_dump -Fp -s -h "$HOSTNAME" -U "$PGUSER" "$DATABASE" | gzip >$FINAL_BACKUP_DIR"$DATABASE"_SCHEMA.sql.gz.in_progress; then
			error "Failed to backup database schema of $DATABASE";
		else
			mv $FINAL_BACKUP_DIR"$DATABASE"_SCHEMA.sql.gz.in_progress $FINAL_BACKUP_DIR"$DATABASE"_SCHEMA.sql.gz;
		fi;
		set +o pipefail;
	done;

###########################
###### FULL BACKUPS #######
###########################

	for SCHEMA_ONLY_DB in ${SCHEMA_ONLY_LIST//,/ }; do
		EXCLUDE_SCHEMA_ONLY_CLAUSE="$EXCLUDE_SCHEMA_ONLY_CLAUSE and datname !~ '$SCHEMA_ONLY_DB'";
	done;

	FULL_BACKUP_QUERY="select datname from pg_database where not datistemplate and datallowconn $EXCLUDE_SCHEMA_ONLY_CLAUSE order by datname;";

	echo -e "\n\nPerforming full backups";
	echo -e "--------------------------------------------\n";

	for DATABASE in `execute psql -h "$HOSTNAME" -U "$PGUSER" -At -c "$FULL_BACKUP_QUERY" postgis`; do
		if [ $ENABLE_PLAIN_BACKUPS = "yes" ]
		then
			echo "Plain backup of $DATABASE";

			echo "$HOSTNAME:$POSTGRESQL_HA_POSTGRESQL_SERVICE_PORT_POSTGRESQL:$DATABASE:$PGUSER:$POSTGRES_PASSWORD" >>$HOME/.pgpass;

			set -o pipefail;
			if ! execute pg_dump -Fp -h "$HOSTNAME" -U "$PGUSER" "$DATABASE" | gzip >$FINAL_BACKUP_DIR"$DATABASE".sql.gz.in_progress; then
				error "Failed to produce plain backup database $DATABASE";
			else
				mv $FINAL_BACKUP_DIR"$DATABASE".sql.gz.in_progress $FINAL_BACKUP_DIR"$DATABASE".sql.gz;
			fi;
			set +o pipefail;
		fi;

		if [ $ENABLE_CUSTOM_BACKUPS = "yes" ]
		then
			echo "Custom backup of $DATABASE";

			if ! execute pg_dump -Fc -h "$HOSTNAME" -U "$PGUSER" "$DATABASE" -f $FINAL_BACKUP_DIR"$DATABASE".custom.in_progress; then
				error "Failed to produce custom backup database $DATABASE";
			else
				mv $FINAL_BACKUP_DIR"$DATABASE".custom.in_progress $FINAL_BACKUP_DIR"$DATABASE".custom;
			fi;
		fi;
	done;

	echo -e "\nAll database backups complete!";

	BACKUP_FILES=$(ls -lart $FINAL_BACKUP_DIR);
	{ echo "$FINAL_BACKUP_DIR"; indent "$BACKUP_FILES"; } | debug;

	return 0;
}

	main "$@";
