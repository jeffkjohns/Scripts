# Boomi Performance Data Capture Scripts


## General Purpose Script
Collects threaddumps and OS level data based on configurable variables.

   ```
SCRIPT_SPAN=240         # How long the whole script should take. Default=240
TD_INTERVAL=30          # How often thread dumps should be taken. Default=30
TOP_INTERVAL=10         # How often top data should be taken. Default=10
TOP_DASH_H_INTERVAL=5    # How often top dash H data should be taken. Default=5
VMSTAT_INTERVAL=5       # How often vmstat data should be taken. Default=5
   ```
## Executing the script:

- Change permissions of the file.
```
sudo chmod 777 boomiPerf_linux.sh
```
- Execute script:
```
./boomiPerf_linux.sh
```
- Checks for any mounts with boomi name. If none found, will prompt for install directory.
- Sets JAVA_HOME based off of prof_jre.cfg found in boomi_installdir/.install4j/
- Collects the following files:
```
topdashH.PID.out
vmstat.out
ps.out
top.out
screen.out
dmesg.out
whoami.out
df-hk.out
threaddump_PID_timstamp.txt
```


# CPU Threshold Script

This scripts monitors CPU and collects threaddumps on all pids found in environment.
- It monitors cpu by performing a top command and scrapping the cpu.  If more than 80% cpu utilization it will start collecting data.
- collects the same data as above.
