#!/bin/bash


get-server () {
    read -p "Please enter the server name: " NAME
    # Check for empty string
    if [[ -z "$NAME" ]]; then
       printf '%s\n' "No NAME entered"
       exit 1
    fi
}

get-server-ip () {
    read -p "Please enter the server IP Address: " IP
    # Check for empty string
    if [[ -z "$IP" ]]; then
       printf '%s\n' "No IP entered"
       exit 1
    fi
}


# Prompt for physical or virtual
while true; do
    read -p "Is the system you are adding physical or virtual (p/v)? " pv
    case $pv in
        [Pp]* ) TYPE="physical";break;;
        [Vv]* ) break;;
        * ) echo;echo "Please answer with p for physical or v for virtual. ";;
    esac
done

# Prompt for function
PS3='Please select any one from the given options (enter 1,2,3,4, or 5): '
options=("Web server only" "DB server only" "LAMP (web & db both) server" "Quit")
select role in "${options[@]}"
do
    case $role in
        "Web server only")
            break;;
        "DB server only")
            break;;
        "LAMP (web & db both) server")
            break;;
        "None of the above (base CentOS)")
            break;;
        "Quit")
            exit;;
        *) echo $role;echo "Invalid option";;
    esac
done

# Prompt for name
get-server
while true; do
    read -p "You entered \"$NAME\".  Is that correct (y/n) " yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) get-server;;
        * ) echo;echo "Please answer with y or n. ";;
    esac
done

# Prompt for IP
get-server-ip
while true; do
    read -p "You entered \"$IP\".  Is that correct (y/n) " yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) get-server-ip;;
        * ) echo;echo "Please answer with y or n. ";;
    esac
done


# Now do the work

# Change case accordingly
if [ "$TYPE" = "physical" ]; then
    NAME=${NAME,,}
else
    NAME=${NAME^^}
fi

# Create the new server
cat <<-EOF > /usr/local/nagios/etc/objects/servers/$NAME.cfg
	define host{
	use                     linux-server            ; Name of host template to use
                                                        ; This host definition will inherit all variables that are defined
	                                                ; in (or inherited by) the linux-server host template definition.
	host_name               NAME
	alias                   NAME
	address                 IP
	}
	EOF
sed -i 's/#.*$//;/^$/d' /usr/local/nagios/etc/objects/servers/$NAME.cfg
sed -i "s/NAME/$NAME/" /usr/local/nagios/etc/objects/servers/$NAME.cfg
sed -i "s/IP/$IP/" /usr/local/nagios/etc/objects/servers/$NAME.cfg

# Add the new server to the correct template
echo "role=$role"
if [ "$role" = "Web server (no db server)" ]; then
    sed -i -E "s/(members.+);(.+)/\1,$NAME;\2/" /usr/local/nagios/etc/objects/hostgroups/web-vm.cfg
    # Need to account for spaces if present in CSV caused by spaces before semi-colon
    sed -i 's/[ ]*,[ ]*/,/g'  /usr/local/nagios/etc/objects/hostgroups/web-vm.cfg
elif [ "$role" = "Database server (no web server)" ]; then
    sed -i -E "s/(members.+);(.+)/\1,$NAME;\2/" /usr/local/nagios/etc/objects/hostgroups/db-vm.cfg
    # Need to account for spaces if present in CSV caused by spaces before semi-colon
    sed -i 's/[ ]*,[ ]*/,/g'  /usr/local/nagios/etc/objects/hostgroups/db-vm.cfg
elif [ "$role" = "Both web AND database server" ]; then
    sed -i -E "s/(members.+);(.+)/\1,$NAME;\2/" /usr/local/nagios/etc/objects/hostgroups/lamp.cfg
    # Need to account for spaces if present in CSV caused by spaces before semi-colon
    sed -i 's/[ ]*,[ ]*/,/g'  /usr/local/nagios/etc/objects/hostgroups/lamp.cfg
# Note we don't need to do anything if "role" = "None of the above (base CentOS)" as all systems
#  are added unless otherwise specified in all.cfg
fi

# Check for config errors
OUTPUT=`/usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg`
if ! [ "echo $OUTPUT | grep 'Things look okay'" ]; then
    echo "Error found!  Please run \"/usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg\" for details"
else
   # No errors found so restart Nagios
   systemctl restart nagios
   echo
   echo "Systems has been added and Nagios has been restarted"
fi

