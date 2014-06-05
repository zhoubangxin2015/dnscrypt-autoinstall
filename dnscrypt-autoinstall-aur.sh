#!/bin/bash

### 
# Installation and autoconfigure script for Arch Linux and dnscrypt.
#
# This script will install dnscrypt and set it up as a daemon service that runs on
# system startup. It also gives you the option to choose which DNSCrypt service to use 
# and easily reconfigure DNSCrypt and uninstall it.
#
# Author: Simon Clausen <kontakt@simonclausen.dk>
# Version: 0.3
#
# TODO: Check for dnscrypt-proxy-git (AUR), disowned packages, failed installs
###

# Are you root?
if (( UID = 0 )); then
	echo "Error!"
	echo ""
	echo "You need to be root to run this script."
	exit 1
fi

# Vars for stuff
LSODIUMINST=false
DNSCRYPTINST=false
WHICHRESOLVER=dnscrypteu
GITURL=https://raw.github.com/simonclausen/dnscrypt-autoinstall/master/conf.d

function config_interface {
	echo ""
	echo "Which DNSCrypt service would you like to use?"
	echo ""
	echo "1) DNSCrypt.eu (Europe - no logs, DNSSEC)"
	echo "2) OpenDNS (Anycast)"
	echo "3) CloudNS (Australia - no logs, DNSSEC)"
	echo "4) OpenNIC (Japan - no logs)"
	echo "5) OpenNIC (Europe - no logs)"
	echo "6) Soltysiak.com (Europe - no logs, DNSSEC)"
	echo ""
	read -p "Select an option [1-6]: " OPTION
	case $OPTION in
		1)
		WHICHRESOLVER=dnscrypteu
		;;
		2)
		WHICHRESOLVER=opendns
		;;
		3)
		WHICHRESOLVER=cloudns
		;;
		4)
		WHICHRESOLVER=opennicjp
		;;
		5)
		WHICHRESOLVER=openniceu
		;;
		6)
		WHICHRESOLVER=soltysiak
		;;
	esac
	return 0
}

function config_do {
	curl -Lo dnscrypt-proxy-$WHICHRESOLVER $GITURL/dnscrypt-proxy-$WHICHRESOLVER
	if [ $DNSCRYPTINST == true ]; then
		systemctl stop dnscrypt-proxy.service
	fi
	
	mv dnscrypt-proxy-$WHICHRESOLVER /etc/conf.d/dnscrypt-proxy
	systemctl enable dnscrypt-proxy.service
	systemctl start dnscrypt-proxy.service
	return 0
}

function remove {
	systemctl disable dnscrypt-proxy.service
	pacman -R dnscrypt-proxy libsodium
	chattr -i /etc/resolv.conf
	mv /etc/resolv.conf-dnscryptbak /etc/resolv.conf
}

# Checks package integrity, including /etc/conf.d/dnscrypt-proxy
if pacman -Qk dnscrypt-proxy; then
	DNSCRYPTINST=true
fi

if pacman -Qk libsodium; then
	LSODIUMINST=true
fi

if [ $DNSCRYPTINST == true ] && [ LSODIUMINST=true ]; then
	echo "Welcome to dnscrypt-autoinstall script."
	echo ""
  	echo "It seems like DNSCrypt was installed and configured."
	echo ""
	echo "What would you like to do?"
	echo ""
	echo "1) Configure another DNSCrypt service"
	echo "2) Uninstall DNSCrypt."
	echo "3) Exit"
	echo ""
		
	read -p "Select an option [1-3]: " OPTION
	case $OPTION in
	  1)
		config_interface && config_do
		echo "Reconfig done. Quitting."
		exit
		;;
			
		2)
		remove
		exit
		;;
			
		3)
		echo "Bye!"
		exit
		;;
	esac

# pacman may ignore dependencies (--nodeps option)
elif [ LSODIUMINST=true ]; then
	echo ""
	echo "Error!"
	echo ""
	echo "It seems like DNSCrypt was installed, but libsodium was not."
	echo ""
	echo "What would you like to do?"
	echo ""
	echo "1) Install libsodium"
	echo "2) Uninstall DNSCrypt."
	echo "3) Exit."
	echo ""
	
	read -p "Select an option [1-3]: " OPTION
	case $OPTION in
	 1)
		pacman -Syu libsodium
		echo "Repair done. Quitting."
		exit
		;;
			
		2)
		remove
		exit
		;;
			
		3)
		echo "Bye!"
		exit 1
		;;
	esac

else
	if nc -z -w1 127.0.0.1 53; then
		echo ""
		echo "Error!"
		echo ""
		echo "It looks like there is already a DNS server"
		echo "or forwarder installed and listening on 127.0.0.1."
		echo ""
		echo "To use DNSCypt, you need to either uninstall it"
		echo "or make it listen on another IP than 127.0.0.1."
		echo ""
		echo "Quitting."
		exit 1
		
	else
		echo ""
		echo "Welcome to dnscrypt-autoinstall script."
		echo ""
		echo "This will install DNSCrypt and autoconfigure it to run as a daemon at start up."
		echo ""
		read -n1 -r -p "Press any key to continue..."
		clear
		echo ""
		echo "Would you like to see a list of supported providers?"
		
		read -p "(DNSCrypt.eu is default) [y/n]: " -e -i n SHOWLIST
		if [ $SHOWLIST == "y" ]; then
			config_interface
		fi
		
		# Prereqs
		pacman -Syu curl gnu-netcat
		
		# Install and enable dnscrypt
		pacman -Syu dnscrypt-proxy libsodium || exit 1
		
		# Arch uses the nobody user for dnscrypt
		# mkdir -p /etc/dnscrypt/run
 		# useradd --system -d /etc/dnscrypt/run -s /bin/false dnscrypt
		
		# Set up configuration
		config_do
		
		# Set up resolv.conf to use dnscrypt
		mv /etc/resolv.conf /etc/resolv.conf-dnscryptbak
		echo "nameserver 127.0.0.1" > /etc/resolv.conf
		echo "nameserver 127.0.0.2" >> /etc/resolv.conf
		
		# Dirty but dependable
		chattr +i /etc/resolv.conf
		
		# Clean up
		cd
		rm -rf dnscrypt-autoinstall
	fi
fi
