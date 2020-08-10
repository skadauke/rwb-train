#!/bin/bash

USER_FILE=/tmp/users.txt
TEMPLATE_USER_DIR=/etc/skel
DEBUG=false

if $DEBUG; then
    set -x
fi

# Deactivate license with docker stop

deactivate() {
    echo "== Exiting =="
    echo " --> TAIL 100 rstudio-server.log"
    tail -100 /var/log/rstudio-server.log
    echo " --> TAIL 100 rstudio-launcher.log"
    tail -100 /var/lib/rstudio-launcher/rstudio-launcher.log
    echo " --> TAIL 100 monitor/log/rstudio-server.log"
    tail -100 /var/lib/rstudio-server/monitor/log/rstudio-server.log

    echo "Deactivating license ..."
    rstudio-server license-manager deactivate >/dev/null 2>&1

    echo "== Done =="
}
trap deactivate EXIT

# Copy course materials into /etc/skel

git clone https://github.com/skadauke/intro-to-r-for-clinicians-rmed2020 /tmp/materials &&
  cp -a /tmp/materials/exercises/ /etc/skel/ &&
  cp -a /tmp/materials/solutions/ /etc/skel/ &&
  rm -rf /tmp/materials

# Create users file

/usr/local/bin/create_users_table.R $USER_PREFIX $N_USERS $PW_SEED $USER_FILE

# Create users

if [[ ! -d $TEMPLATE_USER_DIR ]]; then
    printf 'Error: Template dir %s does not exist.\n' $TEMPLATE_USER_DIR
    exit 1
fi

while IFS=$'\t' read -r USERNAME PASSWORD || [[ -n $USERNAME ]]
do
    # Deal with new line at the end of the file
    if [[ -z "$USERNAME" ]]; then
        continue
    fi

    # Skip existing users
    USER_EXISTS=$(id -u $USERNAME > /dev/null 2>&1; echo $?)
    if [[ "$USER_EXISTS" -eq "0" ]]; then
        printf '# User %s exists, skipping\n' $USERNAME
        continue
    fi

    printf '# Create user %s with password %s\n' $USERNAME $PASSWORD

    # Start useradd command
    CMD="useradd --shell /bin/bash -g users -p \$(openssl passwd -1 $PASSWORD)"

    # Add home dir, unless existing
    HOME_DIR="/home/$USERNAME"
    if [ ! -d "$HOME_DIR" ]; then
        CMD=`printf '%s --create-home' "$CMD"`
    fi

    # Sudo users 001 through 009 (to be used by instructors)
    if [[ $USERNAME =~ 00[1-9] ]]; then
        CMD=`printf '%s %s' "$CMD" "-G sudo"`
    fi

    CMD=`printf '%s %s' "$CMD" "$USERNAME"`

    if $DEBUG; then
        printf 'RUN: %s\n' "$CMD"
    fi

    eval $CMD

done < $USER_FILE

rm -rf $USER_FILE

# Run RSP startup script
# TODO: remove temp user with standard password

/usr/local/bin/startup.sh