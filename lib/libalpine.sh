#!/bin/sh

PREFIX=

PROGRAM=$(basename $0)

: ${ROOT:=/}
[ "${ROOT}" = "${ROOT%/}" ] && ROOT="${ROOT}/"
[ "${ROOT}" = "${ROOT#/}" ] && ROOT="${PWD}/${ROOT}"

# echo if in verbose mode
vecho() {
	if [ -n "$VERBOSE" ]; then
		echo "$@"
	fi
}

# echo unless quiet mode
qecho() {
	if [ -z "$QUIET" ]; then
		echo "$@"
	fi
}

# echo to stderr
eecho() {
	echo "$@" >&2
}

# echo to stderr and exit with error
die() {
	eecho "$@"
	exit 1
}

init_tmpdir() {
	local omask="$(umask)"
	local __tmpd="/tmp/$PROGRAM-${$}-$(date +%s)-$RANDOM"
	umask 077 || die "umask"
	mkdir -p "$__tmpd" || exit 1
	trap "rc=\$?; rm -fr \"$__tmpd\"; exit \$rc" 0
	umask $omask
	eval "$1=\"$__tmpd\""
}

default_read() {
	local n
	read n
	[ -z "$n" ] && n="$2"
	eval "$1=\"$n\""
}


cfg_add() {
	$MOCK lbu_add "$@"
}

# return true if given value is Y, y, Yes, yes YES etc
yesno() {
	case $1 in
	[Yy]|[Yy][Ee][Ss]) return 0;;
	esac
	return 1
}

# Detect if we are running Xen
is_xen() {
	test -d /proc/xen
}

# Detect if we are running Xen Dom0
is_xen_dom0() {
	is_xen && \
	grep -q "control_d" /proc/xen/capabilities 2>/dev/null
}

# list of available network interfaces that aren't part of any bridge or bond
available_ifaces() {
	local iflist= ifpath= iface= i=
	if ! [ -d "$ROOT"/sys/class/net ]; then
		ip link | awk -F: '$1 ~ /^[0-9]+$/ {printf "%s",$2}'
		return
	fi
	sorted_ifindexes=$(
		for i in "$ROOT"/sys/class/net/*/ifindex; do
			[ -e "$i" ] || continue
			printf "%s\t%s\n" "$(cat $i)" $i;
		done | sort -n | awk '{print $2}')
	for i in $sorted_ifindexes; do
		ifpath=${i%/*}
		iface=${ifpath##*/}
		# skip interfaces that are part of a bond or bridge
		if [ -d "$ifpath"/master/bonding ] || [ -d "$ifpath"/brport ]; then
			continue
		fi
		iflist="${iflist}${iflist:+ }$iface"
	done
	echo $iflist
}

# from OpenBSD installer

# Ask for a password, saving the input in $resp.
#    Display $1 as the prompt.
#    *Don't* allow the '!' options that ask does.
#    *Don't* echo input.
#    *Don't* interpret "\" as escape character.
askpass() {
	printf %s "$1 "
	set -o noglob
	$MOCK stty -echo
	read -r resp
	$MOCK stty echo
	set +o noglob
	echo
}

# Ask for a password twice, saving the input in $_password
askpassword() {
	local _oifs="$IFS"
	IFS=
	while :; do
		askpass "Password for $1 account? (will not echo)"
		_password=$resp

		askpass "Password for $1 account? (again)"
		# N.B.: Need quotes around $resp and $_password to preserve leading
		#       or trailing spaces.
		[ "$resp" = "$_password" ] && break

		echo "Passwords do not match, try again."
	done
	IFS=$_oifs
}

# test the first argument against the remaining ones, return success on a match
isin() {
	local _a="$1" _b
	shift
	for _b; do
		[ "$_a" = "$_b" ] && return 0
	done
	return 1
}

# remove all occurrences of first argument from list formed by
# the remaining arguments
rmel() {
	local _a="$1" _b

	shift
	for _b; do
		[ "$_a" != "$_b" ] && printf %s "$_b "
	done
}

# Issue a read into the global variable $resp.
_ask() {
	local _redo=0

	read resp
	case "$resp" in
	!)	echo "Type 'exit' to return to setup."
		sh
		_redo=1
		;;
	!*)	eval "${resp#?}"
		_redo=1
		;;
	esac
	return $_redo
}

# Ask for user input.
#
#    $1    = the question to ask the user
#    $2    = the default answer
#
# Save the user input (or the default) in $resp.
#
# Allow the user to escape to shells ('!') or execute commands
# ('!foo') before entering the input.
ask() {
	local _question="$1" _default="$2"

	while :; do
		printf %s "$_question "
		[ -z "$_default" ] || printf "[%s] " "$_default"
		_ask && : ${resp:=$_default} && break
	done
}

# Ask for user input until a non-empty reply is entered.
#
#    $1    = the question to ask the user
#    $2    = the default answer
#
# Save the user input (or the default) in $resp.
ask_until() {
	resp=
	while [ -z "$resp" ] ; do
		ask "$1" "$2"
	done
}

# Ask for user for y/n until y, yes, n or no is responded
#
#    $1    = the question to ask the user
#    $2    = the default answer
#
#  Returns true/sucess if y/yes was responded. false othewise
ask_yesno() {
	while true; do
		ask "$1" "$2"
		case "$resp" in
			y|yes|n|no) break;;
		esac
	done
	yesno "$resp"
}

# Ask for the user to select one value from a list, or 'done'.
#
# $1 = name of the list items (disk, cd, etc.)
# $2 = question to ask
# $3 = list of valid choices
# $4 = default choice, if it is not specified use the first item in $3
#
# N.B.! $3 and $4 will be "expanded" using eval, so be sure to escape them
#       if they contain spooky stuff
#
# At exit $resp holds selected item, or 'done'
ask_which() {
	local _name="$1" _query="$2" _list="$3" _def="$4" _dynlist _dyndef

	while :; do
		# Put both lines in ask prompt, rather than use a
		# separate 'echo' to ensure the entire question is
		# re-ask'ed after a '!' or '!foo' shell escape.
		eval "_dynlist=\"$_list\""
		eval "_dyndef=\"$_def\""

		# Clean away whitespace and determine the default
		set -o noglob
		set -- $_dyndef; _dyndef="$1"
		set -- $_dynlist; _dynlist="$*"
		set +o noglob
		[ $# -lt 1 ] && resp=done && return

		: ${_dyndef:=$1}
		echo "Available ${_name}s are: $_dynlist."
		printf "Which one %s? (or 'done') " "$_query"
		[ -n "$_dyndef" ] && printf "[%s] " "$_dyndef"
		_ask || continue
		[ -z "$resp" ] && resp="$_dyndef"

		# Quote $resp to prevent user from confusing isin() by
		# entering something like 'a a'.
		isin "$resp" $_dynlist done && break
		echo "'$resp' is not a valid choice."
	done
}

find_modloop_media() {
	devnum=$(mountpoint -d /.modloop) || return
	test -n "$devnum" || return
	modloop_file=$(cat /sys/dev/block/$devnum/loop/backing_file) || return
	test -n "$modloop_file" || return
	# assume that device name and mount point don't contain spaces
	modloop_media=$(df "$modloop_file" | awk 'NR==2{print $6}') || return
	test -n "$modloop_media" || return
	echo "$modloop_media"
}

# Extract fully qualified domain name from current hostname. If none is
# currently set, use the provided fallback.
get_fqdn() {
	local _dn
	_dn=$(hostname -f 2>/dev/null)
	_dn=${_dn#$(hostname -s 2>/dev/null)}
	_dn=${_dn#.}
	echo "${_dn:=$1}"
}
