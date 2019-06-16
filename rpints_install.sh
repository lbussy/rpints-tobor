#!/bin/bash

# Copyright (C) 2019 Lee C. Bussy (@LBussy)

# This file is part of LBussy's Raspberry Pints Tools (RPints-Tools).
#
# Raspberry Pints Tools is free software: you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# Raspberry Pints Tools is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Raspberry Pints Tools. If not, see <https://www.gnu.org/licenses/>.

############
### Global Declarations
############

# General constants
declare THISSCRIPT VERSION PACKAGE VERBOSE REPLY CMDLINE  
declare SCRIPTNAME APTPACKAGES VERBOSE HOMEPATH REALUSER
# Packages to be installed via apt
APTPACKAGES="git apache2 mariadb-server php php-mysql libapache2-mod-php phpmyadmin"
# RPints Archive
# From: https://www.homebrewtalk.com/forum/threads/version-2-release-raspberrypints-digital-taplist-solution.487694/page-116#post-8609646
SOURCE="https://www.homebrewtalk.com/forum/attachments/raspberrypints-2-1-0-000-zip.629862/"
ARCHIVE="RaspberryPints-2.1.0.000.zip"

############
### Init
############

init() {
    # Set up some project variables we won't have running as a curled script
    PACKAGE="RPints-Tools"
    THISSCRIPT="rpints_install.sh"
    VERSION="0.0.0.1"
    CMDLINE="curl -L rpints.brewpiremix.com | sudo bash"
    SCRIPTNAME="${THISSCRIPT%%.*}"
}

############
### Handle logging
############

timestamp() {
    # Add date in '2019-02-26 08:19:22' format to log
    [[ "$VERBOSE" == "true" ]] && length=999 || length=60 # Allow full logging
    while read -r; do
        # Clean and trim line to 60 characters to allow for timestamp on one line
        REPLY="$(clean "$REPLY" $length)"
        # Strip blank lines
        if [ -n "$REPLY" ]; then
            # Add date in '2019-02-26 08:19:22' format to log
            printf '%(%Y-%m-%d %H:%M:%S)T %s\n' -1 "$REPLY"
        fi
    done
}

clean() {
    # Cleanup log line
    local input length
    input="$1"
    length="$2"
    # Strip color codes
    input="$(echo "$input" | sed 's,\x1B[[(][0-9;]*[a-zA-Z],,g')"
    # Strip beginning spaces
    input="$(printf "%s" "${input#"${input%%[![:space:]]*}"}")"
    # Strip ending spaces
    input="$(printf "%s" "${input%"${input##*[![:space:]]}"}")"
    # Squash any repeated whitespace within string
    input="$(echo "$input" | awk '{$1=$1};1')"
    # Log only first $length chars to allow for date/time stamp
    input="$(echo "$input" | cut -c-"$length")"
    echo "$input"
}

log() {
    [[ "$*" == *"-nolog"* ]] && return # Turn off logging
    # Tee all output to log file in home directory
    sudo -u "$REALUSER" touch "$HOMEPATH/$SCRIPTNAME.log"
    exec > >(tee >(timestamp >> "$HOMEPATH/$SCRIPTNAME.log")) 2>&1
}

############
### Command line arguments
############

# usage outputs to stdout the --help usage message.
usage() {
cat << EOF

$PACKAGE $THISSCRIPT version $VERSION

Usage: sudo ./$THISSCRIPT"
EOF
}

# version outputs to stdout the --version message.
version() {
cat << EOF

$THISSCRIPT ($PACKAGE) $VERSION

Copyright (C) 2019 Lee C. Bussy (@LBussy)

This is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published
by the Free Software Foundation, either version 3 of the License,
or (at your option) any later version.
<https://www.gnu.org/licenses/>

There is NO WARRANTY, to the extent permitted by law.
EOF
}

# Parse arguments and call usage or version
arguments() {
    local arg
    while [[ "$#" -gt 0 ]]; do
        arg="$1"
        case "$arg" in
            --h* )
            usage; exit 0 ;;
            --v* )
            version; exit 0 ;;
            * )
            break;;
        esac
    done
}

############
### Make sure command is running with sudo
############

checkroot() {
    local retval shadow
    if [ -n "$SUDO_USER" ]; then REALUSER="$SUDO_USER"; else REALUSER=$(whoami); fi
    if [ "$REALUSER" == "root" ]; then
        # We're not gonna run as the root user
        echo -e "\nThis script may not be run from the root account, use 'sudo' instead."
        exit 1
    fi
    ### Check if we have root privs to run
    if [[ "$EUID" -ne 0 ]]; then
        sudo -n true 2> /dev/null
        retval="$?"
        if [ "$retval" -eq 0 ]; then
            echo -e "\nNot running as root, relaunching correctly."
            sleep 2
            eval "$CMDLINE"
            exit "$?"
        else
            # sudo not available, give instructions
            echo -e "\nThis script must be run with root privileges."
            echo -e "Enter the following command as one line:"
            echo -e "$CMDLINE" 1>&2
            exit 1
        fi
    fi
    # And get the user home directory
    shadow="$( (getent passwd "$REALUSER") 2>&1)"
    retval="$?"
    if [ "$retval" -eq 0 ]; then
        HOMEPATH="$(echo "$shadow" | cut -d':' -f6)"
    else
        echo -e "\nUnable to retrieve $REALUSER's home directory. Manual install may be necessary."
        exit 1
    fi
}

############
### Functions to catch/display errors during execution
############

warn() {
    local fmt
    fmt="$1"
    command shift 2>/dev/null
    echo -e "$fmt"
    echo -e "${@}"
    echo -e "\n*** ERROR ERROR ERROR ERROR ERROR ***" > /dev/tty
    echo -e "-------------------------------------" > /dev/tty
    echo -e "\nSee above lines for error message." > /dev/tty
    echo -e "Setup NOT completed.\n" > /dev/tty
}

die() {
    local st
    st="$?"
    warn "$@"
    exit "$st"
}

############
### Instructions
############

instructions() {
    clear
    cat << EOF

=============================================================================
     -----=====>>>>>     Raspberry Pints Tools     <<<<<=====-----
=============================================================================

You will be presented with some choices during the install. Most frequently
you will see a 'yes or no' choice, with the default choice capitalized like
so: [y/N]. Default means if you hit <enter> without typing anything, you will
make the capitalized choice, i.e. hitting <enter> when you see [Y/n] will
default to 'yes.'

Yes/no choices are not case sensitive. However; passwords, system names and
install paths are. Be aware of this. There is generally no difference between
'y', 'yes', 'YES', 'Yes'; you get the idea. In some areas you are asked for a
path; the default/recommended choice is in braces like: [/var/www/html].
Pressing <enter> without typing anything will take the default/recommended
choice.

EOF
    read -n 1 -s -r -p  "Press any key when you are ready to proceed. " < /dev/tty
    echo -e ""
}

############
### Check for default 'pi' password and gently prompt to change it now
############

checkpass() {
    local user_exists salt extpass match badpwd yn setpass
    user_exists=$(id -u 'pi' > /dev/null 2>&1; echo $?)
    if [ "$user_exists" -eq 0 ]; then
        salt=$(getent shadow "pi" | cut -d$ -f3)
        extpass=$(getent shadow "pi" | cut -d: -f2)
        match=$(python -c 'import crypt; print crypt.crypt("'"raspberry"'", "$6$'${salt}'")')
        [ "${match}" == "${extpass}" ] && badpwd=true || badpwd=false
        if [ "$badpwd" = true ]; then
            echo -e "\nDefault password found for the 'pi' account. This should be changed."
            while true; do
                read -rp "Do you want to change the password now? [Y/n]: " yn  < /dev/tty
                case "$yn" in
                    '' ) setpass=1; break ;;
                    [Yy]* ) setpass=1; break ;;
                    [Nn]* ) break ;;
                    * ) echo "Enter [y]es or [n]o." ;;
                esac
            done
        fi
        if [ -n "$setpass" ]; then
            echo
            until passwd pi < /dev/tty; do sleep 2; echo; done
            echo -e "\nYour password has been changed, remember it or write it down now."
            sleep 5
        fi
    fi
}

############
### Set timezone
###########

settime() {
    local date tz
    date=$(date)
    while true; do
        echo -e "\nThe time is currently set to $date."
        tz="$(date +%Z)"
        if [ "$tz" == "GMT" ] || [ "$tz" == "BST" ]; then
            # Probably never been set
            read -rp "Is this correct? [y/N]: " yn  < /dev/tty
            case "$yn" in
                [Yy]* ) echo ; break ;;
                [Nn]* ) dpkg-reconfigure tzdata; break ;;
                * ) dpkg-reconfigure tzdata; break ;;
            esac
        else
            # Probably been set
            read -rp "Is this correct? [Y/n]: " yn  < /dev/tty
            case "$yn" in
                [Nn]* ) dpkg-reconfigure tzdata; break ;;
                [Yy]* ) break ;;
                * ) break ;;
            esac
        fi
    done
}

############
### Change hostname
###########

host_name() {
    local oldHostName yn sethost host1 host2 newHostName
    oldHostName=$(hostname)
    if [ "$oldHostName" = "raspberrypi" ]; then
        while true; do
            echo -e "\nYour hostname is set to '$oldHostName'. Each machine on your network should"
            echo -e  "have a unique name to prevent issues.\n"
            read -rp "Do you want to change it now, maybe to 'rpints'? [Y/n]: " yn < /dev/tty
            
            case "$yn" in
                '' ) sethost=1; break ;;
                [Yy]* ) sethost=1; break ;;
                [Nn]* ) break ;;
                * ) echo "Enter [y]es or [n]o." ; sleep 1 ; echo ;;
            esac
        done
        echo
        if [ "$sethost" -eq 1 ]; then
            echo -e "You will now be asked to enter a new hostname."
            while
                read -rp "Enter new hostname: " host1  < /dev/tty
                read -rp "Enter new hostname again: " host2 < /dev/tty
                [[ -z "$host1" || "$host1" != "$host2" ]]
            do
                echo -e "\nHost names blank or do not match.\n";
                sleep 1
            done
            echo
            newHostName=$(echo "$host1" | awk '{print tolower($0)}')
            eval "sed -i 's/$oldHostName/$newHostName/g' /etc/hosts"||die
            eval "sed -i 's/$oldHostName/$newHostName/g' /etc/hostname"||die
            hostnamectl set-hostname "$newHostName"
            /etc/init.d/avahi-daemon restart
            echo -e "\nYour hostname has been changed to '$newHostName'.\n"
            echo -e "(If your hostname is part of your prompt, your prompt will not change until"
            echo -e "you log out and in again.  This will have no effect on anything but the way"
            echo -e "the prompt looks.)"
            sleep 5
        fi
    fi
}

############
### Install or update required packages
############

packages() {
    local lastUpdate nowTime pkgOk upgradesAvail pkg didUpdate
    # Run 'apt update' if last run was > 1 week ago
    lastUpdate=$(stat -c %Y /var/lib/apt/lists)
    nowTime=$(date +%s)
    if [ $(("$nowTime" - "$lastUpdate")) -gt 604800 ] ; then
        echo -e "\nLast apt update was over a week ago. Running apt update before updating"
        echo -e "dependencies."
        apt-get update -q||die
        echo -e "\nRunning apt upgrade to upgrade any previously installed system tools and"
        echo -e "installed dependencies."
        apt-get upgrade -y||die
        didUpdate=1
    fi
    
    # Now install any necessary packages if they are not installed
    echo -e "\nChecking and installing required dependencies via apt."
    for pkg in $APTPACKAGES; do
        pkgOk=$(dpkg-query -W --showformat='${Status}\n' "$pkg" | \
        grep "install ok installed")
        if [ -z "$pkgOk" ]; then
            echo -e "\nInstalling '$pkg'."
            apt-get install "$pkg" -y -q=2 < /dev/tty ||die
        fi
    done
    
    # Get list of installed packages with updates available
    if [ ! "$didUpdade" == 1 ]; then
        echo -e "\nUpdating any installed packages which may require it."
        upgradesAvail=$(dpkg --get-selections | xargs apt-cache policy {} | \
            grep -1 Installed | sed -r 's/(:|Installed: |Candidate: )//' | \
        uniq -u | tac | sed '/--/I,+1 d' | tac | sed '$d' | sed -n 1~2p)
        # Loop through the required packages and see if they need an upgrade
        for pkg in $APTPACKAGES; do
            if [[ "$upgradesAvail" == *"$pkg"* ]]; then
                echo -e "\nUpgrading '$pkg'."
                apt-get install "$pkg" -y -q=2||die
            fi
        done
    fi
}

############
### Create a banner
############

banner() {
    local adj
    adj="$1"
    echo -e "\n***Script $THISSCRIPT $adj.***"
}

############
### Check for free space
############

checkfree() {
    local req freek freem freep
    req=2048
    freek=$(df -Pk | grep -m1 '\/$' | awk '{print $4}')
    freem="$((freek / 1024))"
    freep=$(df -Pk | grep -m1 '\/$' | awk '{print $5}')
    
    if [ "$freem" -le "$req" ]; then
        echo -e "\nDisk usage is $freep, free disk space is $freem MB,"
        echo -e "Not enough space to continue setup. Installing $PACKAGE requires"
        echo -e "at least $req MB free space."
        exit 1
    else
        echo -e "\nDisk usage is $freep, free disk space is $freem MB."
    fi
}

############
### Web path setup
############

getwwwpath() {
    # Find web path based on Apache2 config
    echo -e "\nSearching for default web location."
    WWWPATH="$(grep DocumentRoot /etc/apache2/sites-enabled/000-default* |xargs |cut -d " " -f2)"
    if [ -n "$WWWPATH" ]; then
        echo -e "\nFound $WWWPATH in /etc/apache2/sites-enabled/000-default*."
    else
        echo -e "\nSomething went wrong searching for /etc/apache2/sites-enabled/000-default*."
        echo -e "Fix that and come back to try again."
        exit 1
    fi
}

############
### Test apache and PHP
############

testapache() {
    local retval
    echo -e "\nTesting Apache."
    wget -q --spider localhost > /dev/null 2>&1
    retval="$?"
    rm -f "$WWWPATH/index.html"
    if [ "$retval" -ne 0 ]; then
        echo -e "\nERROR: Apache test failed."
        exit 1
    fi
    echo -e "\nTesting PHP."
    echo '<?php phpinfo(); ?>' > "$WWWPATH/test.php"
    wget -q --spider localhost/test.php > /dev/null 2>&1
    retval="$?"
    rm "${WWWPATH:?}/test.php"
    if [ "$retval" -ne 0 ]; then
        echo -e "\nERROR: PHP test failed."
        exit 1
    fi
    echo -e "\nApache and PHP test ok."
}

############
### Add new DBA user
############

dbauser() {
    local password pswd1 pswd2
    echo -e "\nWe will now create a new privileged database user so that system root"
    echo -e "permissions are not needed to administer the database.  The username will"
    echo -e "be 'rpints', please supply a good password below.\n"

    while
        read -sp "Enter new password: " pswd1  < /dev/tty
        echo
        read -sp "Enter new password again: " pswd2 < /dev/tty
        echo
        [[ -z "$pswd1" || "$pswd1" != "$pswd2" ]]
    do
        echo -e "\nPasswords blank or do not match.\n";
        sleep 1
    done
    password="$pswd1"
    echo
    mysql -e "CREATE OR REPLACE USER 'rpints'@'localhost' IDENTIFIED BY '${password}';"
    mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'rpints'@'localhost' WITH GRANT OPTION;"
    mysql -e "FLUSH PRIVILEGES;"
    echo -e "DBA user 'rpints' has been created with the password you supplied.  During"
    echo -e "the Raspberry Pints initial web setup you will be asked for a 'MariaDB"
    echo -e "Username with Root Privileges', sometimes called the 'root user.'  This is"
    echo -e "where you will use the 'rpints' account and password we just created."
    sleep 5
}

############
### Handle the RPints archive
############

doarchive() {
    local archname retval
    archname=${ARCHIVE%.*}
    echo -e "\nDownloading Raspberry Pints archive from Homebrewtalk thread.\n"
	wget -P "$HOMEPATH" -O "$ARCHIVE" "$SOURCE"
	retval="$?"
	if [ "$retval" -ne 0 ]; then
        echo -e "\nERROR: Archive download failed."
        exit 1
    fi
    if [ ! -f "$HOMEPATH/$ARCHIVE" ]; then
        echo -e "\nERROR:  $HOMEPATH/$ARCHIVE not found."
        exit 1
    fi
    echo -e "\nExtracting $HOMEPATH/$ARCHIVE to $WWWPATH."
    unzip -q "$HOMEPATH/$ARCHIVE" -d "$WWWPATH"||die
	retval="$?"
	if [ "$retval" -ne 0 ]; then
        echo -e "\nERROR: Archive unzip failed."
        exit 1
    fi
    shopt -s extglob
    eval cp -R "$WWWPATH/$archname/"* "$WWWPATH"
    rm -fr "${WWWPATH:?}/$archname"
}

############
### Fix WWW path permissions
############

doperms() {
    echo -e "\nFixing file permissions for $WWWPATH."
    chown -R www-data:www-data "$WWWPATH"||warn
    find "$WWWPATH" -type d -exec chmod 2770 {} \; || warn
    find "$WWWPATH" -type f -exec chmod 640 {} \;||warn
    find "$WWWPATH" -type f -regex ".*\.\(py\|sh\)" -exec chmod 770 {} \;||warn
    usermod -a -G www-data "$REALUSER"
}

############
### Instructions
############

complete() {
    local IP
    IP=$(ip -4 addr | grep 'global' | cut -f1  -d'/' | cut -d" " -f6)
    clear
    cat << EOF

=============================================================================
   -----=====>>>>>     Raspberry Pints Tools Complete     <<<<<=====-----
=============================================================================

Raspberry Pints has now been installed to $WWWPATH.

You may have changed the server name, you will have also been added to the
www-data group so that you will be able to browse the local files in the
$WWWPATH directory.  There's also a very good chance that a large number of
packages have been updated.  In order to allow thse changes to be effective,
please reboot your Pi to ensure a clean start.

It may take several minutes for this reboot.  Be patient.

To continue your Raspberry Pints setup, please use your web browser and
navigate to:

    By IP             : http://$IP
    -or- by host name : http://$(hostname).local

EOF
}

############
### Main function
############

main() {
    [[ "$*" == *"-verbose"* ]] && VERBOSE=true # Do not trim logs
    init "$@" # Get constants
    checkroot # Make sure we are su into root
    log "$@" # Start logging
    arguments "$@" # Check command line arguments
    banner "starting" # Pop starting banner
    instructions # Show instructions
    checkpass # Check for default password
    settime # Set timezone
    host_name # Change hostname
    checkfree # TODO:  Figure out size needed
    packages # Install and update required packages
    getwwwpath # Get WWW path
    testapache # Test Apache/PHP
    dbauser # Add a new DBA user
    doarchive # Handle unzipping archive to WWW path
    doperms # Fix permissions in WWW path
    complete # Final user instructions
}

############
### Start the script
############

main "$@" && exit 0
