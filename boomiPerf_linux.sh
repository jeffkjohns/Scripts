#!/bin/bash

# This script is used to collect data for 
# Performance, Hang or High CPU Issues on Linux
# Author: Jeff Johnson
SCRIPT_VERSION="2024.09.25"
###############################################################################
# Variables
###############################################################################
SCRIPT_SPAN=240         # How long the whole script should take. Default=240
TD_INTERVAL=30          # How often thread dumps should be taken. Default=30
TOP_INTERVAL=10         # How often top data should be taken. Default=10
TOP_DASH_H_INTERVAL=5    # How often top dash H data should be taken. Default=5
VMSTAT_INTERVAL=5       # How often vmstat data should be taken. Default=5
NFSIO_INTERVAL=5        # How often nfsiostat data should be taken.  Default = 5
NFSSTAT_INTERVAL=5      # How often nfsstat data should be taken. Default =5

echo -e "\033[1m***********************************************************************\033[0m"
echo -e "\033[1;31mPlease run the script with the owner of the boomi file system, e.g., boomi\033[0m"
echo -e "\033[1m#######################################################################\033[0m"
echo -e "\033[1m#######################################################################\033[0m"
echo ""
echo -e "\033[1;34mPlease modify the following variables to match your needs\033[0m"
echo -e "\033[1;34mAll the script variables are in seconds.\033[0m"
echo -e "\033[1m#######################################################################\033[0m"

echo -e "\033[1;34mSCRIPT_SPAN = Determines how long the script run.\033[0m"
echo -e "\033[1;34mTD_INTERVAL = How often thread dumps should be taken.\033[0m"
echo -e "\033[1;34mTOP_INTERVAL = How often top data should be taken.\033[0m"
echo -e "\033[1;34mTOP_DASH_H_INTEVAL = How often top dash H data should be taken.\033[0m"
echo -e "\033[1;34mVMSTAT_INTERVAL = How often vmstat data should be taken.\033[0m"

##############################################################################
# Define the term to search for in the mounted filesystems
SEARCH_TERM="boomi"
USER_DIR=""

# Function to search for mounted filesystems with the specified term and extract the directory name
search_boomi_mounts() {
    
    MOUNT_DIRS=$(grep -i "$SEARCH_TERM" /proc/mounts 2>/dev/null | awk '{print $2}')

    if [ -n "$MOUNT_DIRS" ]; then
        # Prompt the user to confirm one of the directories
        for dir in $MOUNT_DIRS; do
            read -p "Is '$dir' the correct directory for your Boomi Installation? (Y/N): " CONFIRM
            if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
                USER_DIR="$dir"
                echo "USER_DIR set to: $USER_DIR"
                return  # Exit the function if confirmed
            fi
        done
        echo "No correct directory confirmed."
    else
        echo "No mounts found related to Boomi."
    fi

    # Prompt for a directory if no valid mount was confirmed
    prompt_for_directory
}

# Function to prompt the user for a directory input
prompt_for_directory() {
    while true; do
        read -p "Please enter the Boomi Installation Directory: " USER_DIR
        # Validate if the directory exists
        if [ -d "$USER_DIR" ]; then
            echo "You entered: $USER_DIR"
            return  # Exit the loop when a valid directory is provided
        else
            echo "Directory does not exist. Please try again."
        fi
    done
}

# Call the function to initiate the search
search_boomi_mounts

# If USER_DIR is still empty, meaning no valid directory was found or confirmed
if [ -z "$USER_DIR" ]; then
    echo "No valid Boomi directory was set. Exiting."
    exit 1  # Optional exit with a non-zero status due to failure
else
    echo "Final selected Boomi directory: $USER_DIR"
fi

##############################################################################
# Check JAVA_HOME and Set Java Home
##############################################################################

FILENAME="$USER_DIR/.install4j/pref_jre.cfg"

# Check if the file exists
if [ -f "$FILENAME" ]; then
    # Read the contents of the file into a variable
    JAVA_HOME=$(<"$FILENAME")
else
    JAVA_HOME="$USER_DIR/jre"
fi

##############################################################################
# Check pids
#############################################################################
# Get the process ID of all Java processes
java_pids=$(pgrep -f java)

# Check if there are any Java processes
if [ -z "$java_pids" ]; then
    echo "No Java processes found."
    exit 1
else
    echo "Java Process IDs found:"
    echo "-------------------------------------"

    # Initialize a counter
    count=1

    # Create an associative array to hold commands associated with each PID
    declare -A pid_command_map

    # Iterate through the PIDs and get the associated commands
    for pid in $java_pids; do
        # Get the full command associated with the PID
        command=$(ps -p $pid -o args= | tr -d '\n')

        # Store the PID and command in the associative array
        pid_command_map[$pid]="$command"

        echo -e "\033[1;31m$count)\033[0m \033[1mPID:\033[0m $pid, \033[1mCommand:\033[0m $command"
        ((count++))
    done

    # Add an option for selecting all PIDs
    echo -e "\033[1;31m0)\033[0m \033[1mSelect All PIDs\033[0m"

    echo "-------------------------------------"
    echo "Select process numbers (comma-separated, e.g., 1,2,3), or press Ctrl+C to exit:"
    
    # Read user input
    read -r selection

    IFS=',' read -r -a selected_indices <<< "$selection"
    selected_pids=()
    
    # Validate and collect selected PIDs based on user selection
    for index in "${selected_indices[@]}"; do
        index=$(echo "$index" | xargs)  # Trim whitespace
        if [[ $index =~ ^[0-9]+$ ]]; then
            if [ "$index" -eq 0 ]; then
                # If the user selects "0", add all PIDs
                selected_pids=("${!pid_command_map[@]}")
                break
            elif [ "$index" -gt 0 ] && [ "$index" -le "$(echo ${!pid_command_map[@]} | wc -w)" ]; then
                # Get the PID based on the user's input index
                selected_pid="${!pid_command_map[@]}"  # Get all PIDs
                selected_pid=$(echo $selected_pid | awk "{print \$$index}")
                selected_pids+=("$selected_pid")
            else
                echo "Invalid selection: $index"
            fi
        fi
    done

    # Display selected PIDs
    if [ ${#selected_pids[@]} -eq 0 ]; then
        echo "No valid selections made. Exiting."
    else
        echo "You selected the following Java Process IDs:"
        for spid in "${selected_pids[@]}"; do
            echo "$spid"
        done
    fi
fi

###############################################################################


##########################
# Create output files    #
#                        #
##########################
# Create the screen.out and put the current date in it.
echo > screen.out
date >> screen.out
echo "************************************************************************"
# Starting up
echo $(date) ">> boomPerf.sh script starting..." | tee -a screen.out
echo $(date) ">> Script version:  $SCRIPT_VERSION." | tee -a screen.out


# Display the PIDs which have been input to the script
for i in $*
do
        echo $(date) ">> PROBLEMATIC_PID is:  $selected_pids" | tee -a screen.out
done

# Display the being used in this script
echo $(date) ">> SCRIPT_SPAN = $SCRIPT_SPAN" | tee -a screen.out
echo $(date) ">> TD_INTERVAL = $TD_INTERVAL" | tee -a screen.out
echo $(date) ">> TOP_INTERVAL = $TOP_INTERVAL" | tee -a screen.out
echo $(date) ">> TOP_DASH_H_INTERVAL = $TOP_DASH_H_INTERVAL" | tee -a screen.out
echo $(date) ">> VMSTAT_INTERVAL = $VMSTAT_INTERVAL" | tee -a screen.out
echo $(date) ">> NFSIO_INTERVAL = $NFSI_INTERVAL " | tee -a screen.out
echo $(date) ">>  NFSSTAT_INTERVAL = $NFSSTAT_INTEVAL" | tee -a screen.out

# Collect the user currently executing the script
echo $(date) ">> Collecting user authority data..." | tee -a screen.out
date > whoami.out
whoami >> whoami.out 2>&1
echo $(date) ">> Collection of user authority data complete." | tee -a screen.out
echo $(date) ">> Collecting a ps snapshot..." | tee -a screen.out
    ps -ef | grep java >> ps.out
# Create some of the output files with a blank line at top
echo $(date) ">> Creating output files..." | tee -a screen.out
echo > vmstat.out
echo > top.out
echo > nfsiostat.out
echo > nfsstat_client.out
echo $(date) ">> Output files created:" | tee -a screen.out
echo $(date) ">>      vmstat.out" | tee -a screen.out
echo $(date) ">>      top.out" | tee -a screen.out
echo $(date) ">>      nfsiostat.out" | tee -a screen.out
echo $(date) ">>      nfsstat_client.out" | tee -a screen.out
for i in $*
do
        echo > topdashH.$selected_pids.out
        echo $(date) ">>      topdashH.$selected_pids.out" | tee -a screen.out
done

###############################################################################
#                       #
# Start collection of:  #
#  * top                #
#  * top dash H         #
#  * vmstat             #
#                       #
#########################

# Start the collection of top data.
echo $(date) ">> Starting collection of top data..." | tee -a screen.out
date >> top.out
echo >> top.out
top -bc -d $TOP_INTERVAL -n `expr $SCRIPT_SPAN / $TOP_INTERVAL + 1` >> top.out 2>&1 &
echo $(date) ">> Collection of top data started." | tee -a screen.out

# Start the collection of top dash H data.
echo $(date) ">> Starting collection of top dash H data..." | tee -a screen.out
for i in "${selected_pids[@]}"
do
        date >> topdashH.$i.out
        echo >> topdashH.$i.out
        echo "Collected against PID $i." >> topdashH.$i.out
        echo >> topdashH.$i.out
        top -bH -d $TOP_DASH_H_INTERVAL -n `expr $SCRIPT_SPAN / $TOP_DASH_H_INTERVAL + 1` -p $i >> topdashH.$i.out 2>&1 &
        echo $(date) ">> Collection of top dash H data started for PID $i." | tee -a screen.out
done

# Start the collection of vmstat data.
echo $(date) ">> Starting collection of vmstat data..." | tee -a screen.out
date >> vmstat.out
vmstat $VMSTAT_INTERVAL `expr $SCRIPT_SPAN / $VMSTAT_INTERVAL + 1` >> vmstat.out 2>&1 &
echo $(date) ">> Collection of vmstat data started." | tee -a screen.out

# Start collection of nfs data
echo $(date) " >> Starting collection of nfsio data...." | tee -a screen.out
date >> nfsiostat.out
nfsiostat $NFSIO_INTERVAL $(($SCRIPT_SPAN / $NFSIO_INTERVAL + 1)) >> nfsiostat.out 2>&1 &
echo $(date) ">> Collection of nfsiostat data started." | tee -a screen.out

echo $(date) ">> Starting collection of nfsstat data..." | tee -a screen.out
date >> nfsstat_client.out
nfsstat  $NFSSTAT_INTERVAL 'expr $SCRIPT_SPAN / $NFSSTAT_INTERVAL + 1' -c >> nfsstat_client.out 2>&1 &
echo $(date) ">> Collection of nfsstat data started.." | tee -a screen.out



################################################################################
#                       #
# Start collection of:  #
#  * javacores          #
#  * ps                 #
#                       #
#########################
# Initialize some loop variables
n=1
m=`expr $SCRIPT_SPAN / $TD_INTERVAL`

# Loop to collect thread dumps and ps snapshots
while [ $n -le $m ]
do


    # Collect a thread dump against the problematic pid (passed in by the user)
    echo $(date) ">> Collecting a thread dump..." | tee -a screen.out
for pid in "${selected_pids[@]}"
    do
        timestamp=$(date +"%Y%m%d_%H%M%S")
        # Create unique thread dump file name with PID and timestamp
        output_file="threaddump_${pid}_${timestamp}.txt"
        echo $(date) ">> Writing thread dump for PID $pid to $output_file..." | tee -a screen.out

        # Capture the thread dump and write it to the specific output file
        $JAVA_HOME/bin/jstack -l "$pid" >> "$output_file" 2>&1

        # Confirm thread dump collection
        echo $(date) ">> Collected a thread dump for PID $pid . Output saved to $output_file." | tee -a screen.out
    done

    # Pause for TD_INTERVAL seconds.
    echo $(date) ">> Continuing to collect data for $TD_INTERVAL seconds..." | tee -a screen.out
    sleep $TD_INTERVAL

    # Increment counter
    n=`expr $n + 1`
done


# Final thread dump collection
echo $(date) ">> Collecting the final thread dump..." | tee -a screen.out
for pid in "${selected_pids[@]}"
do
        timestamp=$(date +"%Y%m%d_%H%M%S")
    output_file="threaddump_${pid}_${timestamp}.txt"
    echo $output_file
    $JAVA_HOME/bin/jstack -l "$pid" >> "$output_file" 2>&1
    echo $(date) ">> Collected the final thread dump for PID $pid . Output saved to $output_file." | tee -a screen.out
done


################################################################################
#                       #
# Other data collection #
#                       #
#########################
echo $(date) ">> Collecting other data.  This may take a few moments..." | tee -a screen.out


dmesg > dmesg.out 2>&1
df -hk > df-hk.out 2>&1

echo $(date) ">> Collected other data." | tee -a screen.out
################################################################################
#                       #
# Compress & Cleanup    #
#                       #
#########################
# Brief pause to make sure all data is collected.
echo $(date) ">> Preparing for packaging and cleanup..." | tee -a screen.out
sleep 5

# Tar the output files together
echo $(date) ">> Compressing output files into boomPerf_RESULTS.tar.gz" | tee -a screen.out

# Build a string to contain all the file names
FILES_STRING="nfsstat_client.out nfsiostat.out vmstat.out ps.out top.out screen.out dmesg.out whoami.out df-hk.out threaddump_*.txt topdashH*.out"
for i in $*
do
        TEMP_STRING=" topdashH.$selected_pids.out"
        FILES_STRING="$FILES_STRING $TEMP_STRING"
done

tar -cvf boomiPerf_RESULTS.tar $FILES_STRING

# GZip the tar file to create boomPerf_RESULTS.tar.gz
gzip boomiPerf_RESULTS.tar

# Clean up the output files now that they have been tar/gz'd.
echo $(date) ">> Cleaning up..."
rm $FILES_STRING

echo $(date) ">> Clean up complete."
echo $(date) ">> boomPerf.sh script complete."
echo
echo $(date) ">> Output files are contained within ---->   boomiPerf_$ct-RESULTS.tar.gz.   <----"
################################################################################