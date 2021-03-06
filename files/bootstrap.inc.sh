#!/bin/bash

BOOTSTRAP_DIR="/bootstrap"
DO_CLEANUP=1

function log {
	echo "$1"
	logger -t "bootstrap" -- "${1}";
}

function die {
	[ -n "${1}" ] && log "${1}"
	log "Configuration failed!"
	signal 1
	cleanup
	exit 1
}

function signal {
	log "Sending signal ${1} to stack ${STACK_NAME}, resource ${ASG_NAME}, region ${REGION}."
	cfn-signal -e "${1}" \
		--stack "${STACK_NAME}" \
		--resource "${ASG_NAME}" \
		--region "${REGION}" || log "Failed to send signal."
}

function cleanup {
	if [ "${DO_CLEANUP}" -ne 0 ]; then
		rm -rf "${BOOTSTRAP_DIR}/environment.yml"
	else
		info "No cleanup. Remember to delete ${BOOTSTRAP_DIR}/environment.yml"
	fi
}

## Export global variables
# parameters:
# - launch configuration resorce name
# - autoscaling group name
# - AWS region
# - stack name
#
function set_global {
	export LAUNCH_CONFIG="${1}"
	export ASG_NAME="${2}"
	export REGION="${3}"
	export STACK_NAME="${4}"
}

function cfnInit {
	local resourceName="${1:-$LAUNCH_CONFIG}"
	local region="${2:-$REGION}"
	local stackName="${3:-$STACK_NAME}"

	/usr/local/bin/cfn-init \
		-s "${stackName}" \
		-r "${resourceName}" \
		--region "${region}" \
	|| die "cfn-init failed for ${resourceName}"
}
