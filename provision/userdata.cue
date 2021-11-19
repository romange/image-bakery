package userdata

package_update:  true
package_upgrade: true
groups: [
	"docker",
]

users: [
	"default",
	{
		name:   "dev"
		sudo:   "ALL=(ALL) NOPASSWD:ALL"
		groups: "adm, docker"
		shell:  "/bin/bash"
		ssh_authorized_keys: [
			"ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCano8DfBycFQ/2OxszQ5ZcnHpodZBI4XGsiTK+bw/RxGgwdL6V3/de53DtjZNCltCgfU04fw8wntm2SJ/PyguN8O/Kj3qSD9QHI04CBe2P/Z+GOfJUo528ocIj2PnWHTV8zs5XZVyRaZCLyNfiKTnkfY7EoTHDVJcuUE669v9Q5FDPVBp0eUMGW49Gw1i1z6dXJiv7pfEGyKCcMuGiPnCB357XsuxKzEThazlpuRFWXPqilBOI8hSapMd8G0TXU9xhGNNzpBdrZg6DFvoXX2JChD9sOBNumS0FMv0BEBbZeonMzMHoVU6mMfFMnYAEMJesCXK12vcr440HM8sXC20H",
			"ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC2IaMLRNXtpIQ22pEwaQARoVnbI60qtKBH/O7YUQOWeVsEVM4K+9jx1BOzTHox1vMsV3PHGtkz5UtGaAMfgK8wy1sbC1tXZjPArUVfqgp8/wAe1Buyihs6FR3kWMTevbrBCvucvgYqFUrENAu0A8ixxoOmFrLN+ix470KyHCCQfhw8aVXx8CIHO0L2aukvLwMZ1SEsIolOHu+yniAVTp/sGXDIXLOZe/vjMutV8+iEw2Vbm+pXF/nZzNgBb/i5H8WgcnS/iWYeQd/UeWo5f4mA6aMtZ5EunyC/gM7rwIGcujpx0QeTXOqCy7VD2G+qFFOjBnZaCpJ1MNhHGfwWihLvinHm0hJrxuvxBItpmsUI60qv4uIsIiSArcph0yKvyam70YIEhMj//1tyNgSqRyHVt5FNeZ3PICpi71kHLOv8qHJWIWZ6voqM8XyvyiUEiqFBbvUxYXIhy2/SrYhy11embO1TkcOpUFbjgfC3VNmbdpVUqyMx9oxFJ8zfGOYgU10=",
		]
	}]

_common_pkgs: ["acl", "automake", "autoconf", "binutils", "bison",
	"bzip2", "ca-certificates", "ccache", "cmake-curses-gui", "chrony", "cloc", "curl",
	"dkms", "doxygen", "htop", "iftop",
	"iotop", "flex", "gdb", "graphviz", "git", "golang", "libelf-dev",
	"libtool", "make", "mlocate", "ninja-build", "npm", "parallel", "podman", "runc", "sysstat",
	"tcptrace",
	"python3-pip", "python3-setuptools", "vim", "unzip", "wget", "zip", "iperf3"]

_ubuntu_pkgs: [ "ack-grep", "cmake", "g++", "libunwind-dev", "linux-tools-generic", "libbz2-dev",
	"docker.io", "libhugetlbfs-bin", "libncurses5-dev", "libssl-dev", "libxml2-dev",
	"vim-gui-common", "net-tools", "libboost-fiber-dev", "apt-transport-https"]

// Remove systems that add overhead to syscalls.
runcmd: [
	"systemctl stop apparmor",
	"systemctl disable apparmor",
	"modprobe -rv ip_tables",
	"apparmor_parser -r /etc/apparmor.d/*snap-confine*",
	"apparmor_parser -r /var/lib/snapd/apparmor/profiles/snap-confine*",
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
