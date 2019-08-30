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

if [ $(id -u) != 0 ]; then
	exec sudo "$0" "$@"
fi

# $tmp holds the following files:
# * pid
# * addr
# * log
tmp=$(mktemp -d /tmp/buildctl-daemonless.XXXXXX)
trap "kill \$(cat $tmp/pid); rm -rf $tmp" EXIT

sanitizeCgroups() {
  mkdir -p /sys/fs/cgroup
  mountpoint -q /sys/fs/cgroup || \
    mount -t tmpfs -o uid=0,gid=0,mode=0755 cgroup /sys/fs/cgroup

  mount -o remount,rw none /sys/fs/cgroup

  sed -e 1d /proc/cgroups | while read sys hierarchy num enabled; do
    if [ "$enabled" != "1" ]; then
      # subsystem disabled; skip
      continue
    fi

    grouping="$(cat /proc/self/cgroup | cut -d: -f2 | grep "\\<$sys\\>")" || true
    if [ -z "$grouping" ]; then
      # subsystem not mounted anywhere; mount it on its own
      grouping="$sys"
    fi

    mountpoint="/sys/fs/cgroup/$grouping"

    mkdir -p "$mountpoint"

    # clear out existing mount to make sure new one is read-write
    if mountpoint -q "$mountpoint"; then
      umount "$mountpoint"
    fi

    mount -n -t cgroup -o "$grouping" cgroup "$mountpoint"

    if [ "$grouping" != "$sys" ]; then
      if [ -L "/sys/fs/cgroup/$sys" ]; then
        rm "/sys/fs/cgroup/$sys"
      fi

      ln -s "$mountpoint" "/sys/fs/cgroup/$sys"
    fi
  done

  if ! test -e /sys/fs/cgroup/systemd ; then
    mkdir /sys/fs/cgroup/systemd
    mount -t cgroup -o none,name=systemd none /sys/fs/cgroup/systemd
  fi
}

startBuildkitd() {
	addr=unix:///run/buildkit/buildkitd.sock
	$BUILDKITD $BUILDKITD_FLAGS --addr=$addr >$tmp/log 2>&1 &
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

sanitizeCgroups
startBuildkitd
waitForBuildkitd
$BUILDCTL --addr=$(cat $tmp/addr) $@
