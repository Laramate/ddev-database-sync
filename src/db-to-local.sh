#!/bin/bash

## Description: Laramate: Copies prod database data from remote server to local workspace.
## Usage: db-to-local

#help page content
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    cat <<EOF
🔹Laramate Custom DDEV Command: db-to-local

Description:
    Copies prod database data from remote server to local workspace.

    You need to add following variables to you local .env file:
        REMOTE_USER
        REMOTE_HOST
        REMOTE_PATH_TO_PROJECT
        REMOTE_DB_DATABASE

        Start your application with ddev start or ddev launch first.
        Then you can simply run this custom command.
        Only works with mysql database.

Usage:
    ddev db-to-local [OPTIONS]

Options:
    --help, -h       Prints this help page.

Example:
    ddev db-to-local
EOF
    exit 0
fi


# Load .env into environment
set -a
source .env
set +a

# List of required variable names
required_vars=(
    "REMOTE_USER"
    "REMOTE_HOST"
    "REMOTE_PATH_TO_PROJECT"
    "REMOTE_DB_DATABASE"
    )

# Loop to check each variable
for var in "${required_vars[@]}"; do
  if [[ -z "${!var}" ]]; then
    echo "Error: Variable $var is missing or empty."
    exit 1
  fi
done


# Path configurations
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DUMP_FILE="db_${TIMESTAMP}.sql"
LOCAL_DUMP_DIR=$DDEV_APPROOT
LOCAL_DUMP_FILE_PATH="${LOCAL_DUMP_DIR}/${DUMP_FILE}"
REMOTE_DUMP_FILE_PATH="${REMOTE_PATH_TO_PROJECT}/${DUMP_FILE}"

# Function to log messages with timestamp
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check command status
check_status() {
    local exit_code=$1
    local success_message=$2
    local error_message=$3

    if [ $exit_code -eq 0 ]; then
        log_message "✓ $success_message"
        return 0
    else
        log_message "✗ Error: $error_message"
        return 1
    fi
}

set_up_remote() {
    log_message "Getting remote db informations..."
    #create .my.cnf file on remote Server with env variables stored there
    ssh "${REMOTE_USER}@${REMOTE_HOST}" bash -c "'
        cd \"${REMOTE_PATH_TO_PROJECT}\" || exit 1
        set -a
        source .env
        set +a
        cat > .my.cnf <<EOF
[mysqldump]
user=\${DB_USERNAME}
password=\${DB_PASSWORD}
EOF
        chmod 600 .my.cnf
    '"
}

# Function to create remote database dump
create_remote_dump() {
    log_message "Creating database dump on remote server..."
    ssh "${REMOTE_USER}@${REMOTE_HOST}" "cd $REMOTE_PATH_TO_PROJECT; \
        mysqldump --defaults-extra-file=.my.cnf \
        --routines --triggers --events ${REMOTE_DB_DATABASE} > ${REMOTE_DUMP_FILE_PATH}"

    check_status $? \
        "Database dump created successfully on ${REMOTE_HOST}" \
        "Failed to create database dump" || exit 1
}

# Function to download dump file
download_dump() {
    log_message "Downloading dump file to local machine..."
    scp "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DUMP_FILE_PATH}" "${LOCAL_DUMP_DIR}/"

    check_status $? \
        "Dump file downloaded successfully to ${LOCAL_DUMP_DIR}" \
        "Failed to download dump file" || exit 1
}

# Function to import dump to local database
import_dump() {
    log_message "Importing dump file to local database..."

    ddev mysql < "$LOCAL_DUMP_FILE_PATH"

    check_status $? \
        "Dump file imported successfully to local database" \
        "Failed to import dump file" || exit 1
}

# Function to update user passwords
update_passwords() {
    log_message "Updating user passwords..."
    php artisan tinker --execute="
        \$secret=bcrypt('secret');
        User::all()->each(function(\$u)use(\$secret){
            \$u->update(['password'=>\$secret]);
        });
    "

    check_status $? \
        "User passwords updated successfully" \
        "Failed to update user passwords" || exit 1
}

# Function to cleanup remote dump file
cleanup_dump() {
    log_message "Cleaning up remote dump file..."
    local cleanup_status=0

    # Actually perform the cleanup
    if ssh "${REMOTE_USER}@${REMOTE_HOST}" "rm -f ${REMOTE_DUMP_FILE_PATH}; rm ${REMOTE_PATH_TO_PROJECT}/.my.cnf;"; then
        cleanup_status=0
    else
        cleanup_status=1
    fi

    check_status $cleanup_status \
        "Remote dump file cleaned up successfully" \
        "Failed to clean up remote dump file"

    log_message "Cleaning up local dump file..."
    local cleanup_status=0

    # Actually perform the cleanup
    if rm ${LOCAL_DUMP_FILE_PATH}; then
        cleanup_status=0
    else
        cleanup_status=1
    fi

    check_status $cleanup_status \
        "Local dump file cleaned up successfully" \
        "Failed to clean up local dump file"
}

# Main execution
main() {

    # Execute all steps
    set_up_remote
    create_remote_dump
    download_dump
    import_dump
 #   update_passwords
    cleanup_dump

    log_message "Database backup and import process completed successfully!"
}

# Execute main function
main