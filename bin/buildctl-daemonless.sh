#!/bin/sh
# buildctl-daemonless.sh spawns ephemeral buildkitd for executing buildctl.
#
# Usage: buildctl-daemonless.sh build ...
#
# Flags for buildkitd can be specified as $BUILDKITD_FLAGS .
#
# The script is compatible with BusyBox shell.
set -eu

: ${BUILDCTL=_buildctl}
: ${BUILDKITD=buildkitd}
: ${BUILDKITD_FLAGS=}
: ${ROOTLESSKIT=rootlesskit}

# $tmp holds the following files:
# * pid
# * addr
# * log
tmp=$(mktemp -d /tmp/buildctl-daemonless.XXXXXX)
trap "kill \$(cat $tmp/pid); rm -rf $tmp" EXIT

startBuildkitd() {
	addr=
	helper=
	if [ $(id -u) = 0 ]; then
		addr=unix:///run/buildkit/buildkitd.sock
	else
		addr=unix://$XDG_RUNTIME_DIR/buildkit/buildkitd.sock
		helper=$ROOTLESSKIT
	fi
	$helper $BUILDKITD $BUILDKITD_FLAGS --addr=$addr >$tmp/log 2>&1 &
	pid=$!
	echo $pid >$tmp/pid
	echo $addr >$tmp/addr
}

# buildkitd supports NOTIFY_SOCKET but as far as we know, there is no easy way
# to wait for NOTIFY_SOCKET activation using busybox-builtin commands...
waitForBuildkitd() {
	addr=$(cat $tmp/addr)
	try=0
	max=10
	until $BUILDCTL --addr=$addr debug workers >/dev/null 2>&1; do
		if [ $try -gt $max ]; then
			echo >&2 "could not connect to $addr after $max trials"
			exit 1
		fi
		sleep $(awk "BEGIN{print (100 + $try * 20) * 0.001}")
		try=$(expr $try + 1)
	done
}

su -c sanitize-cgroups
startBuildkitd
waitForBuildkitd
$BUILDCTL --addr=$(cat $tmp/addr) $@
