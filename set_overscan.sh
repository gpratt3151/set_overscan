#!/bin/bash
#########################################################################
# set_overscan.sh v0.3
# Modify overscan on the fly.                                            
# By Russell "ukscone" Davis using RPi mailbox code from Broadcom & Dom Cobley
# 2013-03-10
#
# There is very little, ok no error/sanity checking. I've left that as an exercise
# for the reader :D This is a very simplistic script but it works and i'm sure someone
# will take it and make it all flashy and cool looking.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions, and the following disclaimer,
#    without modification.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. The names of the above-listed copyright holders may not be used
#    to endorse or promote products derived from this software without
#    specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
# IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#########################################################################
# Check we are root or using sudo otherwise why bother?                 #
#########################################################################
# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
        echo "This script must be run by root or using sudo" 1>&2
        exit 1
fi

#########################################################################
# Is overscan enabled? If not the fix it & reboot                       #
#########################################################################
if [ `vcgencmd get_config disable_overscan | awk -F '=' '{print $2}'` -eq "1" ]; then
        whiptail --msgbox  "Overscan is currently disabled. Please add the line disable_overscan to the bottom of the config.txt file in the /boot directory, reboot & then rerun this script." 10 45
        exit 1
fi

#########################################################################
# Function                                                              #
#########################################################################
function get_kc
{
    od -t o1 | awk '{ for (i=2; i<=NF; i++)
                        printf("%s%s", i==2 ? "" : " ", $i)
                        exit }'
}

#########################################################################
# Variables & Constants & create some files                             #
#########################################################################
# Grab terminal capabilities
tty_cuu1=$(tput cuu1 2>&1 | get_kc)            # up arrow
tty_kcuu1=$(tput kcuu1 2>&1 | get_kc)
tty_cud1=$(tput cud1 2>&1 | get_kc)            # down arrow
tty_kcud1=$(tput kcud1 2>&1 | get_kc)
tty_cub1=$(tput cub1 2>&1 | get_kc)            # left arrow
tty_kcub1=$(tput kcud1 2>&1 | get_kc)
tty_cuf1=$(tput cuf1 2>&1 | get_kc)            # right arrow
tty_kcuf1=$(tput kcud1 2>&1 | get_kc)
# Some terminals (e.g. PuTTY) send the wrong code for certain arrow keys
if [ "$tty_cuu1" = "033 133 101" -o "$tty_kcuu1" = "033 133 101" ]; then
    tty_cudx="033 133 102"
    tty_cufx="033 133 103"
    tty_cubx="033 133 104"
fi

# Check for mailbox & if not existing create it.
if [ ! -c mailbox ]; then
       mknod mailbox c 100 0
fi

# Get current overscan values from GPU
TEMP=`./overscan`
GPU_OVERSCAN_TOP=`echo $TEMP | awk -F ' ' '{print $1}'`
GPU_OVERSCAN_BOTTOM=`echo $TEMP | awk -F ' ' '{print $2}'`
GPU_OVERSCAN_LEFT=`echo $TEMP | awk -F ' ' '{print $3}'`
GPU_OVERSCAN_RIGHT=`echo $TEMP | awk -F ' ' '{print $4}'`

# How big is the screen?
TEMP=`fbset | grep 'mode "' | awk -F ' ' '{print $2}' | tr \" \ `
XRES=`echo $TEMP |awk -F 'x' '{print $1}'`
YRES=`echo $TEMP |awk -F 'x' '{print $2}'`
BYTES=`expr $XRES \* $YRES \* 2`

# Create some random data & zero'ed data
head -c $BYTES < /dev/urandom > rand
head -c $BYTES </dev/zero > cleared

########################################################################
# Main()
########################################################################
tty_save=$(stty -g)

stty cs8 -icanon -echo min 10 time 1
stty intr '' susp ''

trap "stty $tty_save; tput cnorm ; exit"  INT HUP TERM

# Going to modify top-left overscan
whiptail --title "Instructions" --msgbox "We are going to dump some random data to the screen. Once the screen is full of random coloured dots use the arrow keys to increase or decrease the top-left corner's overscan & press the q key when finished." 12 50

# We don't need no cursor messing up my pretty screen
tput civis

# Dump some random data to /dev/fb0
cat rand >/dev/fb0

# Set overscan top-left corner
LOOP=1
while [ $LOOP -eq 1 ]; do

	keypress=$(dd bs=10 count=1 2> /dev/null | get_kc)
	case "$keypress" in
        	"$tty_cuu1"|"$tty_kcuu1") ((GPU_OVERSCAN_TOP--));;
        	"$tty_cud1"|"$tty_kcud1"|"$tty_cudx") ((GPU_OVERSCAN_TOP++));;
        	"$tty_cub1"|"$tty_kcub1"|"$tty_cubx") ((GPU_OVERSCAN_LEFT--));;
        	"$tty_cuf1"|"$tty_kcuf1"|"$tty_cufx") ((GPU_OVERSCAN_LEFT++));;
		"161") LOOP=0;; 
    	esac

	./overscan $GPU_OVERSCAN_TOP $GPU_OVERSCAN_BOTTOM $GPU_OVERSCAN_LEFT $GPU_OVERSCAN_RIGHT
done

# Clear the screen
cat cleared >/dev/fb0

# Going to modify bottom-right overscan
whiptail --title "Instructions" --msgbox "We are going to dump some random data to the screen. Once the screen is full of random coloured dots use the arrow keys to increase or decrease the bottom-right corner's overscan & press the q key when finished." 12 50

# No cursor messing up my pretty screen
tput civis

# Dump some random data to /dev/fb0
cat rand >/dev/fb0

# Set overscan bottom-right corner
LOOP=1
while [ $LOOP -eq 1 ]; do
        
	keypress=$(dd bs=10 count=1 2> /dev/null | get_kc)
	case "$keypress" in
        	"$tty_cuu1"|"$tty_kcuu1") ((GPU_OVERSCAN_BOTTOM++));;
        	"$tty_cud1"|"$tty_kcud1"|"$tty_cudx") ((GPU_OVERSCAN_BOTTOM--));;
        	"$tty_cub1"|"$tty_kcub1"|"$tty_cubx") ((GPU_OVERSCAN_RIGHT++)) ;;
        	"$tty_cuf1"|"$tty_kcuf1"|"$tty_cufx") ((GPU_OVERSCAN_RIGHT--));;
        	"161") LOOP=0;;
    	esac
	./overscan $GPU_OVERSCAN_TOP $GPU_OVERSCAN_BOTTOM $GPU_OVERSCAN_LEFT $GPU_OVERSCAN_RIGHT

done

# Clear the screen
cat cleared > /dev/fb0

# Finished so write to /boot/config.txt
echo -ne "# Overscan settings. Written by set_overscan.sh\ndisable_overscan\noverscan_top=$GPU_OVERSCAN_TOP\noverscan_bottom=$GPU_OVERSCAN_BOTTOM\noverscan_left=$GPU_OVERSCAN_LEFT\noverscan_right=$GPU_OVERSCAN_RIGHT\n" >> /boot/config.txt

# Clean up 
rm -f mailbox
rm rand
rm cleared

# Restore stty to old value
stty $tty_save
clear
tput cnorm
