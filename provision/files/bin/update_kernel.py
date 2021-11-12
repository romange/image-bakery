#!/usr/bin/python3

import argparse
import os
import requests
import re
from urllib.request import urlretrieve
import subprocess

MAINLINE_URL = 'http://kernel.ubuntu.com/~kernel-ppa/mainline/'


def get_release_url(arch, version):
    return MAINLINE_URL + 'v' + version + '/' + arch + '/'


def is_cloud_deb(x: str) -> bool:
    return ('lowlatency' not in x) and ('64k_' not in x) and ('snapdragon' not in x)


def get_deb_files(release_url, suffix):
    checksum_url = release_url + 'CHECKSUMS'
    w = requests.get(checksum_url)
    w.raise_for_status()
    regex = re.compile('(linux-.*' + suffix + ')')
    a = regex.findall(w.text)
    return [x for x in set(a) if is_cloud_deb(x)]


def main():
    # Check processor architecture
    uname = os.uname()
    parser = argparse.ArgumentParser(description='Kernel installer')
    parser.add_argument('-v', '--version', type=str, help='Kernel version to install')
    parser.add_argument('-i', action='store_true', help='If true, tries to install the deb files')
    args = parser.parse_args()
    print(f"System Architecture is {uname.machine} {uname.release}")

    if args.version:
        version = args.version.lstrip('v')
    else:
        r = requests.get(MAINLINE_URL)
        regex = re.compile(r'href="v([^ \/]+)/"')
        a = regex.findall(r.text)
        a.sort(reverse=True)
        version = a[0]
        print(f"Latest versions are {a[:15]}")

    print(f"\nFetching version {version}")

    # find url for newest kernel in url = 'http://kernel.ubuntu.com/~kernel-ppa/mainline/'
    # We must download all headers deb first
    amd64_url = get_release_url('amd64', version)
    header = get_deb_files(amd64_url, 'all.deb')
    assert len(header) == 1
    header[0] = amd64_url + header[0]

    # Get platform specific files
    arch = 'amd64' if uname.machine == 'x86_64' else 'arm64'
    release_url = get_release_url(arch, version)
    debs = get_deb_files(release_url, arch + '.deb')
    debs = [release_url + x for x in debs]
    debs.extend(header)

    debs = { k: '/tmp/' + os.path.basename(k) for k in debs}
    print(f"Downloading files {list(debs.keys())}")

    for url, dst_file in debs.items():
        if not os.path.exists(dst_file):
            urlretrieve(url, dst_file)
    if args.i:
        print("installing deb files")
        subprocess.check_output(['sudo', 'dpkg', '-i'] + list(debs.values()))


if __name__ == "__main__":
    # execute only if run as a script
    main()
