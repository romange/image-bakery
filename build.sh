#!/bin/bash

set -e

if ! hash packer &> /dev/null
then
    echo "packer could not be found, install from https://www.packer.io/downloads"
    exit 1
fi

if ! hash cue &> /dev/null
then
    echo "cue could not be found, install from https://github.com/cue-lang/cue/releases"
    exit 1
fi

build_only=''
region='us-east1'  # gcp default
additional_vars=''

for ((i=1;i <= $#;));do
  arg=${!i}
  case "$arg" in
    --azure)
    build_only="azure-arm.dev"
    region='centralus'
    shift
  ;;
  --gcp)
    build_only="googlecompute.dev"
    shift
  ;;
  --aws)
    build_only="amazon-ebs.dev"
    additional_vars='--var project=""'
    shift
  ;;
  -*|--*=|*=*) # bypass flags
    i=$((i + 1))
  ;;
  *)
   echo "Unsupported argument ${arg}"
   exit 1
  ;;
  esac
done

if [[ $build_only == "" ]]; then
  echo "One of --aws|--gcp|--azure must be set"
  exit 1
fi

userdatafile=$(mktemp -u -t userdata.yml.XXXX)
echo "Exporting userdata to ${userdatafile}"
echo '#cloud-config' > $userdatafile
cue export provision/userdata.cue -t osf=ubuntu --out yaml >> $userdatafile

packcmd=(packer build --only=$build_only --var region=$region --var userdata_file=$userdatafile
         ${additional_vars} $@ dev.pkr.hcl)

echo "${packcmd[@]}"
"${packcmd[@]}"
