#!/usr/bin/env bash

set -o pipefail
MD5_OF_256_ZERO=348a9791dc41b89796ec3808b5b5262f

die() {
	echo "$*" 1>&2
	exit 1
}

usage() {
	die "usage: check available|logrotate|daily-apt|all"
}

check() {
	local cmd=$1
	sync
	shift 1
	case "$cmd" in
	available)
		check file /var/lib/dpkg/available
	;;
	logrotate)
		check file /var/lib/logrotate/status
	;;
	daily-apt)
		if test -e /etc/cron.daily/apt; then
			if test -L /etc/cron.daily/apt; then
				true
			else
				false
			fi
		else
			true
		fi
	;;
	file)
		local file=$1
		if 	test -f "$file" &&
			SIZE=$(wc -c < "$file") &&
			test "$SIZE" -ge 256; then
			md5=$(dd if=$file count=1 bs=256 2>/dev/null | md5sum | cut -f1 -d' ') &&
			if test "$md5" != "${MD5_OF_256_ZERO}"; then
				true
			else
				false
			fi
		else
			true
		fi
	;;
	all)
		rc=0
		check available || rc=$(expr $rc + 1)
		check logrotate || rc=$(expr $rc + 2)
		check daily-apt || rc=$(expr $rc + 4)
		return $rc
	;;
	*)
		die "usage: check available|logrotate|daily-apt|all"
	;;
	esac
}

fix() {
	local cmd=$1
	shift 1
	case "$cmd" in
	available)
		if ! check available; then
			if test -f "/var/lib/dpkg/available-old"; then
				cp /var/lib/dpkg/available-old /var/lib/dpkg/available &&
				check available
			fi
		fi
	;;
	logrotate)
		if ! check logrotate; then
			rm /var/lib/logrotate/status
		fi
	;;
	daily-apt)
		if ! check daily-apt; then
			block() {
				mkdir -p /etc/cron.orig &&
				mv /etc/cron.daily/apt /etc/cron.orig &&
				ln -sf ../cron.patch/apt /etc/cron.daily
			}
			export -f block
			with-rw bash -c block
		fi
	;;
	all)
		fix available
		fix logrotate
		fix daily-apt
		check all
	;;
	*)
		die "usage: fix available|logrotate|daily-apt|all"
	;;
	esac
}

main() {
	local cmd=$1
	shift 1
	case "$cmd" in
	check)
		if "$cmd" "$@"; then
			echo true
			true
		else
			rc=$?
			echo false
			return $rc
		fi
	;;
	fix)
		if "$cmd" "$@"; then
			echo "ok"
		else
			rc=$?
			echo "failed...$rc"
			return $rc
		fi
	;;
	*)
		usage
	;;
	esac
}

main "$@"