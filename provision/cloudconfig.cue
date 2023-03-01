package userdata

package_update:  true
package_upgrade: true
groups: [
    "docker",
]

// To allow packer to connect to newer images that prevent from ssh-rsa
// to be an accepted authentication algorithm. See https://github.com/hashicorp/packer/issues/11656
// TODO: to remove around 2023 (by that time packer will probably be released with the fix).
bootcmd: [
    "echo PubkeyAcceptedKeyTypes=+ssh-rsa > /etc/ssh/sshd_config.d/packer.conf"
]

apt: sources: grafana: {
    source: "deb https://packages.grafana.com/oss/deb stable main"

    // Extracted with wget -q -O - https://packages.grafana.com/gpg.key  | gpg --list-packets -
    keyid: "9E439B102CF3C0C6"
}

users: [
    "default",
    {
        name:   "dev"
        sudo:   "ALL=(ALL) NOPASSWD:ALL"
        groups: "adm, docker"
        shell:  "/bin/bash"
        ssh_authorized_keys: [
            "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCano8DfBycFQ/2OxszQ5ZcnHpodZBI4XGsiTK+bw/RxGgwdL6V3/de53DtjZNCltCgfU04fw8wntm2SJ/PyguN8O/Kj3qSD9QHI04CBe2P/Z+GOfJUo528ocIj2PnWHTV8zs5XZVyRaZCLyNfiKTnkfY7EoTHDVJcuUE669v9Q5FDPVBp0eUMGW49Gw1i1z6dXJiv7pfEGyKCcMuGiPnCB357XsuxKzEThazlpuRFWXPqilBOI8hSapMd8G0TXU9xhGNNzpBdrZg6DFvoXX2JChD9sOBNumS0FMv0BEBbZeonMzMHoVU6mMfFMnYAEMJesCXK12vcr440HM8sXC20H roman",
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIArcl9h9QrhN/lZo71+8CuvhxKLEdMgfUGtz1FG0MX2O ari",
            "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDIR5PsRAetrkpRSA7BnZI1SWnjwQItgaGMuqIVANIbXllz50yI37NBEAibfUV3x/rh2D+qxbmbzJVTVLJ7VIX8oVvjrStuPNnScw2jdCKQwJDAzCiYi8eKOIHH9LbS5RDbpYPuUSGzV1NXgEJ2k246gMvUdeHQ6TWRm/4FIX17XOaX/oiEfRvOCST7/vslMNTFKOQ8K6ZZ28JxDgYaDTjr+3D3hwFI/zJCXasoigqyWtRLDHgn3rWgOFeTITYjiuXPhirhSbH/fJWhKG211hSh0fU/YFBrsoeq5jg46KgFzqJl+jMXiPFDyhUefoixdFZz04c92gIlck5p/tZlc3zt oded",
            "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDhlQvbo9A743IuosAbB6DCQHtG21ySj3L9JBpnpfWgSYfD/PK4qfVma9uQzySIL3wfIy5sVBo6Z+tNUHI+6K8KIBBJCHLcgO0UICQ1Y0qhtmWYNDJ0Qo3YVHU1EdODuHzn/tmkJciitEFBDTchjMv4nF3sy/zUn7rd2GY9zsJ2d+Vsjd1RuXzcjnxiot+PfT+jf2Vpv2osLfntzhRbBCbdqndyCTGcu2I9hd0Cx4At2H/JvtfqtXqTUMKiXIl1gJJxk6u2nCHxM4VTi8YLKu5o3Xxg9P+V22Z4s7P5n2mkRB0hv08+nIVA/dw/00vx6CujbqWT1Y+YfpMsr8SNuXwmgKAllyrsAviqHJL6mmnKa5Ya07ks13S33GRFGXULIkqilLuXV9fhopAVC1aIEd/VKdhaxw5FPoSwknk4UjrZRY9fEVdve7hSMuY4r8fwn90ixBYAzaihQki5OVjj2vYIyYOVe2EhkM2IXywKKZom6up5PUq2rWVomdeqe8jzmm0= vlad",
        ]
    },
    for x in #service_users
    {
      name: x
      no_create_home: true
      system: true
      shell: "/bin/false"
    },

    ]

#service_users: ["prometheus", "node_exporter"]

// podman exists starting from 21.10 and later.
_common_pkgs: ["acl", "automake", "autoconf", "binutils", "bison",
    "bzip2", "ca-certificates", "ccache", "cmake-curses-gui", "chrony", "cloc", "curl",
    "dkms", "doxygen", "htop", "iftop", "iperf3",
    "iotop", "flex", "gdb", "graphviz", "git", "golang", "libelf-dev",
    "libtool", "make", "mlocate", "ninja-build", "npm", "parallel", "runc", "sysstat",
    "tcptrace",
    "python3-pip", "python3-setuptools", "vim", "unzip", "wget", "zip", "zstd", ]

_ubuntu_pkgs: [ "ack-grep", "apt-transport-https", "cmake", "grafana", "g++",
    "libunwind-dev", "linux-tools-generic", "libbz2-dev",
    "docker.io", "libboost-fiber-dev", "libhugetlbfs-bin", "libncurses5-dev",
    "libssl-dev", "libxml2-dev", "libzstd-dev", "net-tools", "numactl", "pixz", "redis-tools",
    "vim-gui-common", "libevent-2.1-7", "python-is-python3"]

runcmd: [
    // Remove systems that add overhead to syscalls.
    "systemctl stop apparmor",
    "systemctl disable apparmor",
    "modprobe -rv ip_tables",
    "apparmor_parser -r /etc/apparmor.d/*snap-confine*",
    "apparmor_parser -r /var/lib/snapd/apparmor/profiles/snap-confine*",
    // install prometheus
    "mkdir /etc/prometheus /var/lib/prometheus",
    "sudo chown prometheus:prometheus /etc/prometheus /var/lib/prometheus",

    """
    download_prometheus() {
      local PRJ=$1
      local VER=$2

      if [ "$(uname -m)" = "x86_64" ]; then
        local arch="amd64"
      elif [ "$(uname -m)" = "aarch64" ]; then
        local arch="arm64"
      else
        echo "Unknown architecture: $(uname -m). Only x86_64 and aarch64 are supported."
        exit 1
      fi

      local BASE=https://github.com/prometheus/${PRJ}/releases/download
      local NAME=${PRJ}-${VER}.linux-${arch}

      wget -q ${BASE}/v${VER}/${NAME}.tar.gz
      tar xvfz ${NAME}.tar.gz
      mv ${NAME} ${PRJ}
    }

    mkdir /run/me && cd /run/me

    download_prometheus memcached_exporter 0.9.9
    mv memcached_exporter/memcached_exporter /usr/local/bin/

    download_prometheus node_exporter 1.3.1
    mv node_exporter/node_exporter /usr/local/bin/
    download_prometheus prometheus 2.34.0
    mv prometheus/prometheus /usr/local/bin/
    cp -r prometheus/consoles /etc/prometheus
    cp -r prometheus/console_libraries /etc/prometheus
    chown -R prometheus:prometheus /etc/prometheus/consoles
    chown -R prometheus:prometheus /etc/prometheus/console_libraries
    """,
]

// _os_version is limited to either al2 or ubuntu.
// the value is injected via '-t osf=...' argument
_os_flavour: "al2" | "ubuntu" @tag(osf)

_cloud: "aws" | "gcp" | "azure" @tag(cloud)
_cloud_pkgs: [...]

if _os_flavour == "ubuntu" {
    packages: _common_pkgs + _ubuntu_pkgs + _cloud_pkgs
}

_azure_key: """
   -----BEGIN PGP PUBLIC KEY BLOCK-----
   Version: GnuPG v1.4.7 (GNU/Linux)

   mQENBFYxWIwBCADAKoZhZlJxGNGWzqV+1OG1xiQeoowKhssGAKvd+buXCGISZJwT
   LXZqIcIiLP7pqdcZWtE9bSc7yBY2MalDp9Liu0KekywQ6VVX1T72NPf5Ev6x6DLV
   7aVWsCzUAF+eb7DC9fPuFLEdxmOEYoPjzrQ7cCnSV4JQxAqhU4T6OjbvRazGl3ag
   OeizPXmRljMtUUttHQZnRhtlzkmwIrUivbfFPD+fEoHJ1+uIdfOzZX8/oKHKLe2j
   H632kvsNzJFlROVvGLYAk2WRcLu+RjjggixhwiB+Mu/A8Tf4V6b+YppS44q8EvVr
   M+QvY7LNSOffSO6Slsy9oisGTdfE39nC7pVRABEBAAG0N01pY3Jvc29mdCAoUmVs
   ZWFzZSBzaWduaW5nKSA8Z3Bnc2VjdXJpdHlAbWljcm9zb2Z0LmNvbT6JATUEEwEC
   AB8FAlYxWIwCGwMGCwkIBwMCBBUCCAMDFgIBAh4BAheAAAoJEOs+lK2+EinPGpsH
   /32vKy29Hg51H9dfFJMx0/a/F+5vKeCeVqimvyTM04C+XENNuSbYZ3eRPHGHFLqe
   MNGxsfb7C7ZxEeW7J/vSzRgHxm7ZvESisUYRFq2sgkJ+HFERNrqfci45bdhmrUsy
   7SWw9ybxdFOkuQoyKD3tBmiGfONQMlBaOMWdAsic965rvJsd5zYaZZFI1UwTkFXV
   KJt3bp3Ngn1vEYXwijGTa+FXz6GLHueJwF0I7ug34DgUkAFvAs8Hacr2DRYxL5RJ
   XdNgj4Jd2/g6T9InmWT0hASljur+dJnzNiNCkbn9KbX7J/qK1IbR8y560yRmFsU+
   NdCFTW7wY0Fb1fWJ+/KTsC4=
   =J6gs
   -----END PGP PUBLIC KEY BLOCK-----
   """

if _cloud == "azure" {
    apt: sources: "azure-cli.list": {
        source: "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ focal main"
        key:    _azure_key
    }
    _cloud_pkgs: ["azure-cli"]
}

if _cloud != "azure" {
    _cloud_pkgs: []
}
