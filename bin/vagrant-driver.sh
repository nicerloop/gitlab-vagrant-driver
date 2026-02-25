#!/bin/sh
set -e

test -n "$VAGRANT_DRIVER_DEBUG" && set -x

vagrant_driver_version=0.0.1

stage="$1" && shift || true
stage="${stage:?missing argument}"

config() {
	while [ $# -gt 0 ]; do
		case "$1" in
		box=*) box=${1#box=} ;;
		provider=*) provider=${1#provider=} ;;
		template=*) template=${1#template=} ;;
		*) echo "unknown config parameter $1" >&2 && exit 1 ;;
		esac
		shift
	done
	box="${box:?missing parameter}"
	job_box="${CUSTOM_ENV_JOB_IMAGE:-$box}"
	case "$job_box" in
	*"windows"*)
		guest_shell="powershell"
		vagrant_communicator="winrm"
		guest_temp="C:/temp"
		;;
	*"macos"*)
		guest_shell="sh"
		vagrant_communicator="ssh"
		guest_temp="/tmp"
		;;
	*) echo "unsupported guest os for box $job_box" >&2 && exit 1 ;;
	esac
	test -n "$VAGRANT_DRIVER_DEBUG" && cat >driver.env <<EOF
provider=$provider
template=$template
job_box=$job_box
vagrant_communicator=$vagrant_communicator
guest_temp=$guest_temp
EOF
	cat <<EOF
{
  "driver": {
    "name": "vagrant",
    "version": "$vagrant_driver_version"
  },
  "shell": "$guest_shell",
  "job_env": {
	"provider": "$provider",
	"template": "$template",
	"job_box": "$job_box",
	"vagrant_communicator": "$vagrant_communicator",
	"guest_temp": "$guest_temp"
  }
}
EOF
}

prepare() {
	# shellcheck source=/dev/null
	test -n "$VAGRANT_DRIVER_DEBUG" && . "driver.env"
	box_name=$(echo "$job_box" | cut -d ':' -f 1)
	if [ "$box_name" != "$job_box" ]; then
		box_version=$(echo "$job_box" | cut -d ':' -f 2)
		version_args="--box-version $box_version"
	fi
	test -n "$provider" && provider_args="--provider $provider"
	test -n "$template" && template_args="--template $template"
	# shellcheck disable=SC2086
	vagrant init $version_args $template_args "$box_name" --force
	# shellcheck disable=SC2086
	vagrant up $provider_args
}

run() {
	# shellcheck source=/dev/null
	test -n "$VAGRANT_DRIVER_DEBUG" && . "driver.env"
	script="$1" && shift || true
	script="${script:?missing argument}"
	script_name=$(basename "$script")
	description="$1" && shift || true
	test -n "$description" && echo "$description"
	vagrant upload "$script" "$guest_temp/$script_name" >/dev/null 2>&1
	vagrant "$vagrant_communicator" --command "$guest_temp/$script_name"
}

cleanup() {
	test -f Vagrantfile && (vagrant destroy --force || vagrant destroy --force)
}

case "$stage" in
config | prepare | run | cleanup) "$stage" "$@" ;;
*) echo "unknown stage $stage" >&2 && exit 1 ;;
esac
