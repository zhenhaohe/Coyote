#alveo-u55c 1-10 
#external ip: 10.1.212.171,10.1.212.172,10.1.212.173,10.1.212.174,10.1.212.175,10.1.212.176,10.1.212.177,10.1.212.178,10.1.212.179,10.1.212.180
#internal ip: 10.253.74.66,10.253.74.70,10.253.74.74,10.253.74.78,10.253.74.82,10.253.74.86,10.253.74.90,10.253.74.94,10.253.74.98,10.253.74.102
#fpga ip    : 10.253.74.68,10.253.74.72,10.253.74.76,10.253.74.80,10.253.74.84,10.253.74.88,10.253.74.92,10.253.74.96,10.253.74.100,10.253.74.104

#alveo-u50d 1-4
#external ip:10.1.212.162,10.1.212.163,10.1.212.164,10.1.212.165
#internal ip:10.253.74.50,10.253.74.54,10.253.74.58,10.253.74.62

#alveo-u250 1-4
#external ip:10.1.212.121,10.1.212.122,10.1.212.123,10.1.212.124
#internal ip:10.253.74.10,10.253.74.14,10.253.74.18,10.253.74.22

# external_ip="10.1.212.173,10.1.212.174,10.1.212.175,10.1.212.176,10.1.212.177,10.1.212.178,10.1.212.179,10.1.212.180"
# fpga_ip="10.253.74.76,10.253.74.80,10.253.74.84,10.253.74.88,10.253.74.92,10.253.74.96,10.253.74.100,10.253.74.104"

# read server ids from user
echo "Enter u55c machine ids (space separated):"
read -a SERVID
# SERVID=(9 10)

HOST_FILE=./host
FPGA_FILE=./fpga
rm -f $HOST_FILE $FPGA_FILE

num_nodes=0
for ID in ${SERVID[@]}; do
	external_ip+="10.1.212.$((ID + 170)),"
    fpga_ip+="10.253.74.$(((ID-1) * 4 + 68)),"
    num_nodes=$((num_nodes+1))
    HOST_LIST+="alveo-u55c-$(printf "%02d" $ID) "
    echo "10.253.74.$(((ID-1) * 4 + 66))">>$HOST_FILE
	echo "10.253.74.$(((ID-1) * 4 + 68))">>$FPGA_FILE
done

external_ip=${external_ip::-1}
fpga_ip=${fpga_ip::-1}

echo "$external_ip"
echo "$fpga_ip"


SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
echo "Script Dir: $SCRIPT_DIR"

size=$1
num_msg=$2
tx_num_batch=$3
rx_batch_timer=$4
exeMode=$5
offloadMode=$6

LOG_DIR=$SCRIPT_DIR/log/t_${num_nodes}_s_${size}_m_${num_msg}_b_${tx_num_batch}_rt_${rx_batch_timer}_offload_${offloadMode}_mode_${exeMode}/
echo "Log Dir: $LOG_DIR"

mkdir -p $LOG_DIR
rm $LOG_DIR/*

fpga_ip_list=`echo $fpga_ip | cut -d ',' -f1`

for id in `seq 2 $num_nodes` 
do
	nth=`echo $fpga_ip | cut -d ',' -f$id`
	fpga_ip_list="$fpga_ip_list,$nth"
done

echo "FPGA IPs: $fpga_ip_list"

mpirun -n $num_nodes -outfile-pattern "$LOG_DIR/rank_%r_stdout.log" -errfile-pattern "$LOG_DIR/rank_%r_stderr.log" -f $HOST_FILE $SCRIPT_DIR/../build/main -s $size -m $num_msg -f $fpga_ip_list -b $tx_num_batch -r $rx_batch_timer -x $exeMode -o $offloadMode -d "$SCRIPT_DIR/log" >/dev/tty

SLEEPTIME=$(((num_nodes-1)*2 + 15))
sleep $SLEEPTIME

parallel-ssh -H "$HOST_LIST" "kill -9 \$(ps -aux | grep main | awk '{print \$2}')"


