size=(64)
num_msg=2000    
num_batch=(1)
rx_batch_timer=1000
exeMode=(1)


SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

for x in "${exeMode[@]}"
do
    for s in "${size[@]}" 
    do
        for b in "${num_batch[@]}" 
        do
            $SCRIPT_DIR/run.sh $s $num_msg $b $rx_batch_timer $x
        done
    done
done
