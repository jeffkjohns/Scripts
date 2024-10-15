#
# This script is used to collect data for 
# ': Performance, Hang or High CPU Issues on Linux'
# Author Jeff Johnson
SCRIPT_VERSION=2024.09.25
###############################################################################
#                        #
# Variables              # 
#                        #
##########################
SCRIPT_SPAN=240         # How long the whole script should take. Default=240
TD_INTERVAL=30    # How often thread dumps should be taken. Default=30
TOP_INTERVAL=10          # How often top data should be taken. Default=60
TOP_DASH_H_INTERVAL=5    # How often top dash H data should be taken. Default=5
VMSTAT_INTERVAL=5        # How often vmstat data should be taken. Default=5
###############################################################################
# * All values are in seconds.
# * All the 'INTERVAL' values should divide into the 'SCRIPT_SPAN' by a whole  
#   integer to obtain expected results.

###############################################################################

# Function to check system CPU utilization
check_cpu_utilization() {
    # Get CPU utilization from the top command
    cpu_util=$(top -b -n 1 | awk '/%Cpu/ {print $2}' | cut -d. -f1)
    echo "Current CPU Utilization: ${cpu_util}%"
    
    # Check if CPU utilization is greater than or equal to 8
    if (( cpu_util >= 80 )); then
        return 0  # CPU usage exceeds 80%
    else
        return 1  # CPU usage is below 80%
    fi
}

##############################################################################
#   Check if the JAVA_HOME is set
##############################################################################
if [ -z "${JAVA_HOME}" ]; then
  echo "JAVA_HOME is not set. "
  echo "Please enter your path to JAVA Home directory  :   example  - /mnt/boomi/jre"
read JAVA_HOME
echo "JAVA_HOME set to ${JAVA_HOME}"
else
        echo "Starting the script."
        
fi
# Start monitoring CPU utilization until it reaches 80%
echo "Monitoring CPU utilization..."
while true; do
    check_cpu_utilization
    if [ $? -eq 0 ]; then
        echo "CPU utilization has reached 80%, proceeding with the script execution."
        break  # Exit the loop if CPU usage is 80% or higher
    else
        echo "CPU utilization is below 80%, checking again in 10 seconds..."
        sleep 10  # Wait before checking again
    fi
done
selected_pids=("${!pid_command_map[@]}")

##############################################################################
#   Check pids
##############################################################################
#!/bin/bash

# Get the process ID of all Java processes
java_pids=$(pgrep -f java)

# Check if there are any Java processes
if [ -z "$java_pids" ]; then
    echo "No Java processes found."
    exit 1
else
    echo "Java Process IDs found:"
    echo "-------------------------------------"

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
echo $(date) ">> Output files created:" | tee -a screen.out
echo $(date) ">>      vmstat.out" | tee -a screen.out
echo $(date) ">>      top.out" | tee -a screen.out
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

################################################################################
#                       #
# Start collection of:  #
#  * javacores          #
#  * ps                 #
#                       #
#########################
# Initialize some loop variables
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
FILES_STRING="vmstat.out ps.out top.out screen.out dmesg.out whoami.out df-hk.out threaddump_*.txt topdashH*.out"
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