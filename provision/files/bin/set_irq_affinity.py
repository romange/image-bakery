#!/usr/bin/python3

import argparse
import os
import sys
import re


def parse_proc_interrupts(filt: str):
    fields = []
    ret = {}

    with open('/proc/interrupts', 'r') as f:
        for line in f:
            if not fields:
                fields = line.split()  # CPU0 CPU1 etc
                continue

            #   0:         46          0          0          0   IO-APIC-edge      timer
            # no tabs, but there are multiple spaces
            line = re.sub(r'\s{2,}', '  ', line.strip())
            counter, rest = line.split(':', 1)
            parts = rest.strip().split('  ')
            if len(parts) < len(fields):
                break

            identification = parts[len(fields):]
            identification = identification[-2:]
            name = identification[0]
            kind = identification[1] if len(identification) > 1 else ''
            if filt not in kind:
                continue
            ret[counter] = {'kind': kind, 'name': name}

            # this doesn't process the parts on the end
            # for k, v in zip(fields, parts):
            #    ret[counter][k] = int(v)  # all of the CPUn values are ints

    return ret


def parse_online_cpus():
    online_cpus = []
    with open('/sys/devices/system/cpu/online') as f:
        lst = f.readline().strip()
        lst = lst.split(',')
        for rec in lst:
            rec = rec.split('-')
            s = int(rec[0])
            e = int(rec[1]) if len(rec) == 2 else s
            for indx in range(s, e + 1):
                online_cpus.append(indx)
    return online_cpus


def main():
    # Check processor architecture
    parser = argparse.ArgumentParser(description='irq assigner')
    parser.add_argument(
        '-i', type=str, help='network device name (aka ens5 or eth0)', dest='dev', required=True)
    parser.add_argument('-n', action='store_true',
                        dest='dry_run', help='dry-run')
    parser.add_argument('-c', type=int, dest='cpuid', help='cpu id to assign')
    parser.add_argument('--all', action='store_true',
                        help='assign all cpu ids')
    parser.add_argument('--start-cpu', type=int,
                        dest='start_id', help='start cpu id')
    args = parser.parse_args()
    if not args.dry_run and os.geteuid() > 0:
        print('Please run as root')
        sys.exit(1)

    if args.all and args.cpuid:
        print('can not set both --all and -c')
        sys.exit(1)

    inters = parse_proc_interrupts(args.dev)
    assert inters

    # print(inters)
    IRQS = list(inters.keys())
    online_cpus = parse_online_cpus()
    # print(online_cpus)

    if len(online_cpus) < len(IRQS) and not args.cpuid:
        print(
            f'There are less online cpus than network IRQs: {len(online_cpus)} vs {len(IRQS)}')
        sys.exit(1)

    if args.cpuid:
        assert args.cpuid in online_cpus

    ii = 0
    ci = args.start_id if args.start_id else 0
    aff_list = {}
    while ci < len(online_cpus):
        cpuid = args.cpuid
        if not cpuid:
            cpuid = online_cpus[ci]
            ci += 1
        irq = IRQS[ii]
        aff_list.setdefault(irq, []).append(cpuid)
        ii += 1
        if ii >= len(IRQS):
            if args.all:
                ii = 0
            else:
                break
    # print(aff_list)
    for k, v in aff_list.items():
        irq_path = f'/proc/irq/{k}/smp_affinity_list'
        str_ids = [str(i) for i in v]
        print(f'Setting affinity list of irq {k} to {str_ids}')
        if not args.dry_run:
            with open(irq_path, 'w') as f:
                f.write(','.join(str_ids))


if __name__ == "__main__":
    main()
