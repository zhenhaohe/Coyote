size=(128)
num_msg=128    
num_batch=(16)
rx_batch_timer=100
exeMode=(0)
offloadMode=(0)


SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

for x in "${exeMode[@]}"
do
    for s in "${size[@]}" 
    do
        for b in "${num_batch[@]}" 
        do
            $SCRIPT_DIR/run.sh $s $num_msg $b $rx_batch_timer $x $offloadMode
        done
    done
done
