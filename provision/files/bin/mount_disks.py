#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import argparse
import sys
import logging
import re
from subprocess import run, PIPE
from typing import Dict, Any, List
from pathlib import Path
import json


def get_next_vol() -> str:
    id = 1
    p = Path('/mnt')
    for i in p.glob('vol*'):
        m = re.match(r'vol(\d+)', i.name)
        if not m:
            continue
        mid = int(m.group(1))
        if not i.is_mount():
            return f'/mnt/vol{mid}'
        if mid >= id:
            id = mid + 1
    res = f'/mnt/vol{id}'
    Path(res).mkdir()
    return res


def lsblk(disk: str = ''):
    # list only block devices (259)
    lsblk_j = run(f"lsblk -I259 -o +UUID,FSTYPE -J {disk}", shell=True, check=True, stdout=PIPE)
    blockdevices = json.loads(lsblk_j.stdout)['blockdevices']
    return blockdevices


def mount(device_list: List[Dict[str, Any]]):
    for item in device_list:
        type = item['type']
        children = item.get('children', None)
        name = '/dev/' + item['name']
        if type == 'disk' and not children:
            # create a partition under the partionless nvme disk. 'sfdisk -T' prints types.
            # type=83 is a linux partition.
            # Originally it was 'sudo sfdisk {name} -N 1' but it did not work on AWS.
            # Removing -N 1 fixed the problem.
            # TODO: to check on gcp whether it works there.
            run(f"echo 'type=83' | sudo sfdisk {name}", shell=True, check=True)
            children = lsblk(name)  # reread partitions again
            assert children

        if children:
            assert type == 'disk'
            logging.info("children  %s", children)
            mount(children)
            continue

        assert type == 'part'
        fstype = item['fstype']
        mountpoint = item.get('mountpoint', None) or item.get('mountpoints', None)
        logging.info("Processing item %s", item)
        if not fstype:
            logging.info(f"Formatting disk {name}")
            run(f"mkfs -t xfs {name}", shell=True)

        if not mountpoint or mountpoint == [None]:
            mountpoint = get_next_vol()
            logging.info(f"Mounting disk {name} to {mountpoint}")
            run(f"mount -o noatime,discard,nofail {name} {mountpoint}", shell=True, check=True)
            run(f"chmod a+w {mountpoint}", shell=True, check=True)


def main():
    logging.basicConfig(format='%(asctime)-15s %(message)s')
    logging.getLogger().setLevel(logging.INFO)

    parser = argparse.ArgumentParser(description='')
    parser.add_argument(
        '-d', type=int, help='disk like nvme1n1', dest='disk')

    args = parser.parse_args()
    mount(lsblk())
    return 0


if __name__ == '__main__':
    sys.exit(main())
