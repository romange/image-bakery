#!/bin/bash

set -e

env

PATH=$PATH:/usr/local/bin
TF=/tmp/files

if [[ $(uname -i) == "aarch64" ]]; then
  ARCH='aarch64'
else
  ARCH='x86'
fi

install_ena() {
  echo "************* Install ENA ****************"

  local ENA_VER=2.7.0
  local ENA_SRC="/usr/src/amzn-drivers-${ENA_VER}"

  cd /tmp
  wget -nv https://github.com/amzn/amzn-drivers/archive/refs/tags/ena_linux_${ENA_VER}.tar.gz
  mkdir -p $ENA_SRC
  tar -xvf ena_linux_${ENA_VER}.tar.gz -C $ENA_SRC --strip-components=1
  mv $TF/ena.conf $ENA_SRC/dkms.conf

  dkms add -m amzn-drivers -v $ENA_VER
  dkms build -m amzn-drivers -v $ENA_VER
  dkms install -m amzn-drivers -v $ENA_VER
  cd -
}

install_cmake() {
  CMAKE_VER=$1
  wget -q https://github.com/Kitware/CMake/releases/download/v${CMAKE_VER}/cmake-${CMAKE_VER}.tar.gz
  tar xfz cmake-*gz && cd cmake-*
  ./bootstrap && gmake -j4 cmake cpack ctest
  gmake install
  cd - && rm -rf cmake-*
}

install_mold() {
  ARCH=`uname -m`
  MOLD_VER=1.2.1
  BASE_URL=https://github.com/rui314/mold/releases/download
  curl -L -s $BASE_URL/v${MOLD_VER}/mold-$MOLD_VER-$ARCH-linux.tar.gz -o mold.tgz
  mkdir mold && tar xvfz mold.tgz -C mold --strip-components=1  && rm mold.tgz
  mv mold/bin/* /usr/local/bin/
  mv mold/libexec /usr/local/
  ls /usr/local/bin/
  mold --version
  rm -rf mold
}

install_zellij() {
  ARCH=`uname -m`
  BASE_URL=https://github.com/zellij-org/zellij/releases/download
  VER=0.31.3
  curl -L -s $BASE_URL/v${VER}/zellij-$ARCH-unknown-linux-musl.tar.gz -o zellij.tgz
  tar xvfz zellij.tgz && rm zellij.tgz
  mv zellij /usr/local/bin/
  zellij setup --generate-completion  bash > /etc/bash_completion.d/zellij
}

echo "********* Install Basics Server Environment ********"

if [[ $PACKER_BUILDER_TYPE == "amazon-ebs" ]]; then
  pip3 install -U git-remote-codecommit awscli

  ARTPATH=$(aws ssm get-parameters --names artifactdir  --query "Parameters[*].{Value:Value}" --output text)

  echo "Running: 'aws s3 cp s3://$ARTPATH/bin/$ARCH/s5cmd'"
  aws s3 cp --recursive s3://$ARTPATH/bin/$ARCH/ /usr/local/bin/
  zstd -d --rm /usr/local/bin/*.zst || true
  chmod a+x /usr/local/bin/*
  s5cmd version
  install_ena 
  
  mv $TF/changedns.sh /var/lib/cloud/scripts/per-boot/
  mv $TF/aws_init.sh /var/lib/cloud/scripts/per-instance/
elif [[ $PACKER_BUILDER_TYPE == "googlecompute" ]]; then
  ARTPATH=$(gcloud secrets  versions access latest --secret=artifactdir)
  gsutil cp gs://$ARTPATH/bin/$ARCH/* /usr/local/bin/
  chmod a+x /usr/local/bin/*
else 
  echo "Unsupported build type ${PACKER_BUILDER_TYPE}"
  exit 1
fi

apt install -y linux-tools-`uname -r`


# Dispatch files that were put by packer.yaml into /tmp/files
mv $TF/huge_pages.service /etc/systemd/system/
mv $TF/huge_multiuser.service /etc/systemd/system/
mv $TF/node_exporter.service /etc/systemd/system/
mv $TF/prometheus.service /etc/systemd/system/
mv $TF/local.conf /etc/sysctl.d/
mv $TF/prometheus.yml /etc/prometheus/
mv $TF/grafana_sources.yaml /etc/grafana/provisioning/datasources/
systemctl enable huge_multiuser.service

echo "* soft nofile 65535" >> /etc/security/limits.conf
echo "* soft core unlimited" >> /etc/security/limits.conf

# Disable mitigations
sed -i 's/\(^GRUB_CMDLINE_LINUX=".*\)"/\1 mitigations=off"/' /etc/default/grub
update-grub

wget -nv -P /etc/bash_completion.d/ https://raw.githubusercontent.com/imomaliev/tmux-bash-completion/master/completions/tmux

echo "********* User Setup ********"
root_gist=https://gist.githubusercontent.com/romange/43114d544e2981cfe4a6/raw

cd /home/dev

for i in .gitconfig .bash_aliases .bashrc .tmux.conf supress.txt
 do
  wget -qN $root_gist/$i
done
mkdir -p .aws projects bin /root/.aws .tmux .config/htop
cp $TF/reset .tmux/
mv $TF/.bash_profile .
mv $TF/htoprc .config/htop/

mv $TF/bin/* bin/

# . /etc/os-release
# if [[ $VERSION_ID == "2" ]]; then  # AL2 Linux
#   install_cmake 3.18.2
#   echo "alias ninja=ninja-build" >> .bash_aliases
# fi

# Finally, fix permissions.
chown -R dev:dev /home/dev


if false; then
  echo "********* Install BOOST ********"
  BVER=1.77.0
  BOOST=boost_${BVER//./_}   # replace all . with _

  url="https://boostorg.jfrog.io/artifactory/main/release/${BVER}/source/$BOOST.tar.bz2"
  echo "Downloading from $url"

  mkdir -p /tmp/boost && pushd /tmp/boost
  wget -nv ${url} -O $BOOST.tar.bz2
  tar -xjf $BOOST.tar.bz2

  booststap_arg="--prefix=/opt/${BOOST} --without-libraries=graph_parallel,graph,wave,test,mpi,python"
  cd $BOOST
  boostrap_cmd=`readlink -f bootstrap.sh`

  echo "Running ${boostrap_cmd} ${booststap_arg}"
  ${boostrap_cmd} ${booststap_arg} || { cat bootstrap.log; return 1; }
  b2_args=(define=BOOST_COROUTINES_NO_DEPRECATION_WARNING=1 link=shared variant=release debug-symbols=on
            threading=multi --without-test --without-math --without-log --without-locale --without-wave
            --without-regex --without-python -j4)

  echo "Building targets with ${b2_args[@]}"
  ./b2 "${b2_args[@]}" cxxflags='-std=c++14 -Wno-deprecated-declarations'
  ./b2 install "${b2_args[@]}" -d0
  ln -s /opt/${BOOST} /opt/boost
fi

install_mold
install_zellij

echo "************* Checkout Helio ****************"
cd  /home/dev/projects
git clone https://github.com/romange/helio
cd helio && ./blaze.sh -release -DUSE_MOLD=ON
cd build-opt && ninja base
chown dev:dev -R /home/dev/projects
