#!/bin/sh
#
# Packman.vim is a simple Vim plugin/package manager.
#
# Version: 20170505
# http://code.arp242.net/packman.vim
#
# Copyright © 2017 Martin Tournoij <martin@arp242.net>
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
	echo "    update     Update existing plugins; don't update new."
	echo "    orphan     Remove 'orphaned' packages no longer in the config."
	echo
	echo "If no mode is given we will install new plugins and update existing."
}

rp() {
	# TODO: readlink -f doesn't always work on all platforms (specifically, I
	# think it won't work on OSX).
	readlink -f "$1"
}

# Filter commented out repos
filter_comments() {
	local new_want=""
	for repo in "$@"; do
		[ $(echo "$repo" | head -c1) = "#" ] && continue
		[ -z $(echo "$repo" | tr -d ' ') ] && continue
		new_want=$(printf "$new_want\n$repo")
	done
	echo "$new_want"
}

# Show versions
cmd_version() {
	local mode=$1; shift
	local want=$*

	for repo in $want; do
		local repo=$(echo "$repo" | tr -d ' ')
		local dirname=$(echo "$repo" | cut -d/ -f2)

		printf "%-5s -> %-30s %s" "$mode" "$repo"

		if [ ! -e "$dirname" ]; then
			echo "Not installed"
		else
			(
				cd "$dirname"
				git log -n1 --date=short --format='%h %ad %s'
			)
		fi
	done
}

# Find orphans
find_orphans() {
	local want=$*
	local installed=$(find . -maxdepth 1 -a -type d)
	local orphans=""

	for repo in $installed; do
		echo "$want" | grep -q ${repo#./} && continue
		orphans=$(printf "$orphans\n$(rp "$repo")")
	done
	echo "$orphans"
}

# Remove orphans
rm_orphans() {
	local orphans=$*

	if [ $(printf "$orphans" | wc -l) -eq 0 ] ; then
		echo "No orphans found."
		return
	fi

	for repo in $orphans; do
		echo "  $repo"
	done
	printf "Remove the above directories? [y/N] "
	read answer
	if [ "$answer" != "y" ]; then
		echo "Okay then."
		exit 0
	fi

	for repo in $orphans; do
		# Use -f for the git dir since that's write-protected by default.
		rm -fr "$repo/.git"
		rm -r "$repo"
	done
}

# First argument is "start" or "opt". This is here just for display purposes.
# Second argument is the mode: "install", "update", or "" (empty) for both
# All the rest are GitHub repos.
cmd_install() {
	local dir=$1; shift
	local mode=$1; shift
	local want=$*
	local total=$(echo "$want" | wc -l)
	local i=0

	for repo in $want; do
		i=$(($i + 1))
		repo=$(echo "$repo" | tr -d ' ')
		dirname=$(echo "$repo" | cut -d/ -f2)

		# Update existing
		if [ -e "$dirname" ]; then
			[ "$mode" = "install" ] && continue
			printf "($i/$total) "
			echo "updating '$dir/$dirname' from '$repo'"
			(
				cd "$dirname"
				git pull --quiet
				[ -d doc ] && vim -u NONE --noplugins +':helptags doc' +:q >/dev/null 2>&1 &
			)
		# Install new
		else
			[ "$mode" = "update" ] && continue
			printf "($i/$total) "
			echo "cloning '$repo' to '$dir/$dirname'"
			git clone --quiet "git@github.com:$repo" "$dirname"
			(
				cd "$dirname"
				[ -d doc ] && vim -u NONE --noplugins +':helptags doc' +:q >/dev/null 2>&1 &
			)
		fi
	done
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

want_opt=$(filter_comments $want_opt)
want_start=$(filter_comments $want_start)
mode=${1:-}
case "$mode" in
	version)
		(cd opt   && cmd_version opt   $want_opt)
		(cd start && cmd_version start $want_start)
		;;
	install)
		(cd opt   && cmd_install opt   install $want_opt)
		(cd start && cmd_install start install $want_start)
		;;
	update)
		(cd opt   && cmd_install opt   update $want_opt)
		(cd start && cmd_install start update $want_start)
		;;
	orphan)
		orphans=$(cd opt   && find_orphans $want_opt)
		orphans=${orphans}$(cd start && find_orphans $want_start)
		rm_orphans $orphans
		;;
	"")
		(cd opt   && cmd_install opt   "" $want_opt)
		(cd start && cmd_install start "" $want_start)
		;;
	*)
		usage
		exit 1
		;;
esac


# The MIT License (MIT) 
# 
# Copyright © 2017 Martin Tournoij
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
