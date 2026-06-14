#!/bin/sh
set -e

export LANG=C.UTF-8
export LC_ALL=C.UTF-8
cd "$(dirname "$0")"
test -d bento || git clone https://github.com/chef/bento.git
case "$(uname -m)" in
	x86_64) pkr_arch="x86_64" ;;
	arm64) pkr_arch="aarch64" ;;
	*) echo "Unsupported architecture: $(uname -m)" >&2 && exit 1 ;;
esac
(
	cd bento
	git fetch
	git switch --detach v5.1.0
	git reset --hard
	git apply ../bento-v5.1.0.patch
	packer init -upgrade packer_templates
	packer build -force -only=virtualbox-iso.vm -var-file=os_pkrvars/windows/windows-11-"$pkr_arch".pkrvars.hcl packer_templates
)
box="./bento/builds/build_complete/windows-11-$pkr_arch.virtualbox.box"
vagrant box add --force "bento/windows-11" "$box"
