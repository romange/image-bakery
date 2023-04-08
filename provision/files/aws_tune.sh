#!/bin/bash

INSTANCE_TYPE=$(cloud-init query ds.meta-data.instance-type)

# assuming there is a single mac
MAC=$(cloud-init query ds.meta-data.network.interfaces.macs -l)
CPU_NUM=$(nproc)
echo "Instance type: $INSTANCE_TYPE CPU: $CPU_NUM"

IFACE=$(ip -o link | grep $MAC | awk -F: '{print $2}' | tr -d ' ')

ethtool -C $IFACE adaptive-rx on

if (( $CPU_NUM <= 8 )); then
  ethtool -L $IFACE combined $(( $CPU_NUM / 2 ))
fi

setup_queues()
{
    local IFACE=$1
    local que_prefix="/sys/class/net/$IFACE/queues"
    local q_count=$(ls -1 $que_prefix/*/xps_cpus | wc -l)
    local cpuid=1
    for (( i=0; i<$q_count; i++ ))
    do
        local MASKN=$((1<<$cpuid))
		MASK=$(printf "%X" $MASKN)
        echo "Setting RPS/XPS for $IFACE queue $i to CPU $cpuid (mask $MASK)"
        echo $MASK > $que_prefix/tx-$i/xps_cpus
        echo $MASK > $que_prefix/rx-$i/rps_cpus
        cpuid=$((cpuid+2))
    done
}

set_irqs()
{
    local IFACE=$1
    local irqs=(`cat  /proc/interrupts | grep $IFACE | cut -d":" -f1`)
    local cpuid=1
    local irqargs=""

    for irq in ${irqs[*]}
    do
        echo $cpuid > /proc/irq/$irq/smp_affinity_list
        cpuid=$((cpuid+2))
        irqargs="$irqargs --banirq=$irq "
    done
    # we do not append because subsequent restarts will just add more lines.
    echo "IRQBALANCE_ARGS=$irqargs" > /etc/default/irqbalance
}

set_irqs  $IFACE
setup_queues $IFACE
systemctl restart irqbalance


FREEMEM=$(cat /proc/meminfo | grep MemAvailable | awk '{print $2}')
LARGE_PAGE_CNT=$(echo "$FREEMEM*0.9/2048" | bc)
# echo $LARGE_PAGE_CNT | tee /proc/sys/vm/nr_hugepages
# /proc/sys/vm/nr_hugepages
# should decrease PageTables: