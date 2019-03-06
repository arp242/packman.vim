#!/bin/sh
#
# Packman.vim is a simple Vim plugin/package manager.
#
# Version: 20190307
# http://code.arp242.net/packman.vim
#
# Copyright © 2017-2019 Martin Tournoij <martin@arp242.net>
# See the bottom of this file for the full copyright.
#

set -euC
IFS="
"

usage() {
	echo "$0 [mode]"
	echo
	echo "mode can be:"
	echo "    version    Show last commit for all installed plugins."
	echo "    install    Install new plugins; don't update existing."
	echo "    update     Update existing plugins; don't install new."
	echo "    orphans    Remove 'orphaned' packages no longer in the config."
	echo
	echo "If no mode is given it will install new plugins and update existing plugins."
}

make_helptags() {
	vim -u NONE +':helptags ALL' +:q >/dev/null 2>&1 || :
}

# Filter commented out repos.
filter_comments() {
	for repo in "$@"; do
		[ $(echo "$repo" | head -c1) = "#" ] && continue
		[ -z $(echo "$repo" | tr -d ' ') ] && continue
		echo ${repo%#*}
	done
}

prefix_with() {
	local prefix=$1
	shift
	for repo in "$@"; do
		echo "$prefix$repo"
	done
}

# Show versions.
cmd_version() {
	for dir in "$@"; do
		local dir=$(echo "$dir" | tr -d ' ')
		local pkg_dir=$(echo "$dir" | cut -d/ -f1)
		local repo=$(echo "$dir" | cut -d/ -f2,3)
		local plugin_name=$(basename "$repo")
		local destdir="$pkg_dir/$plugin_name"

		printf "%-36s %s" "$dir"
		if [ ! -e "$destdir" ]; then
			echo "Not installed"
		else
			git -C "$destdir" log -n1 --date=short --format='%h %ad %s' || :
		fi
	done
}

cmd_orphans() {
	local in_config=""
	for dir in "$@"; do
		local dir=$(echo "$dir" | tr -d ' ')
		local pkg_dir=$(echo "$dir" | cut -d/ -f1)
		local repo=$(echo "$dir" | cut -d/ -f2,3)
		local plugin_name=$(basename "$repo")
		local destdir="$pkg_dir/$plugin_name"

		in_config=$(printf "$destdir\n$in_config")
	done

	rm_orphans "$(find_orphans "$in_config")"
}

find_orphans() {
	local in_config="$@"
	local installed="$(find . -maxdepth 2 -a -type d)"
	for dir in $installed; do
		echo "$in_config" | grep -q ${dir#./} && continue
		echo $dir
	done
}

rm_orphans() {
	if [ -z "$@" ]; then
		echo "No orphans found."
		return
	fi

	for repo in $@; do
		echo "  $repo"
	done
	printf "Remove these directories? [y/N] "
	read answer
	if [ "$answer" != "y" ]; then
		echo "Okay then."
		exit 0
	fi

	for repo in $@; do
		# Use -f for the git dir since that's write-protected by default.
		rm -fr "$repo/.git"
		rm -vr "$repo"
	done
}

# First argument is "start" or "opt". This is here just for display purposes.
# Second argument is the mode: "install", "update", or "" (empty) for both
# All the rest are GitHub repos.
cmd_install() {
	local mode=$1
	shift
	local want="$*"

	local total=$(echo "$want" | wc -l)
	local i=0
	local ret=0

	for dir in $want; do
		local dir=$(echo "$dir" | tr -d ' ')
		local pkg_dir=$(echo "$dir" | cut -d/ -f1)
		local repo=$(echo "$dir" | cut -d/ -f2,3)
		local plugin_name=$(basename "$repo")
		local destdir="$pkg_dir/$plugin_name"
		local i=$((i + 1))

		# Update existing
		if [ -e "$destdir" ]; then
			[ "$mode" = "install" ] && continue
			printf "%-8s" "($i/$total)"
			echo "updating '$destdir' from '$repo'"
			do_update || ret=$?
		# Install new
		else
			[ "$mode" = "update" ] && continue
			printf "%-8s" "($i/$total)"
			echo "cloning '$repo' to '$destdir'"
			do_install || ret=$?
		fi
	done
	make_helptags
	return $ret
}

do_update() {
	git -C "$destdir" pull --quiet || return $?
}

do_install() {
	git clone --quiet "git@github.com:$repo" "$destdir" || return $?
}

if [ -f "$HOME/.vim/packman.conf" ]; then
	. "$HOME/.vim/packman.conf"
elif [ -f ./packman.conf ]; then
	. ./packman.conf
else
	echo "error: cannot find packman.conf in $HOME/.vim/ or ./"
	exit 1
fi

install_dir=${install_dir:-"$HOME/.vim/pack/plugins"}
mkdir -p "$install_dir/start"
mkdir -p "$install_dir/opt"
cd "$install_dir"

want_opt=$(filter_comments ${want_opt:-})
want_start=$(filter_comments ${want_start:-})
want_combined="$(prefix_with opt/ $want_opt)
$(prefix_with start/ $want_start)"

mode=${1:-}
case "$mode" in
	version) cmd_version         $want_combined   ;;
	orphans) cmd_orphans         $want_combined   ;;
	install) cmd_install install $want_combined   ;;
	update)  cmd_install update  $want_combined   ;;
	"")      cmd_install ""      $want_combined   ;;
	*)
		usage
		exit 1
		;;
esac

# The MIT License (MIT)
#
# Copyright © 2017-2019 Martin Tournoij <martin@arp242.net>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the “Software”), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# The software is provided "as is", without warranty of any kind, express or
# implied, including but not limited to the warranties of merchantability,
# fitness for a particular purpose and noninfringement. In no event shall the
# authors or copyright holders be liable for any claim, damages or other
# liability, whether in an action of contract, tort or otherwise, arising
# from, out of or in connection with the software or the use or other dealings
# in the software.
