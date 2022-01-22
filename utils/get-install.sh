#!/usr/bin/env sh
#env

if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script, please use root to install nq-agent"
    exit 1
fi

_exists() {
	cmd="$1"
	if [ -z "$cmd" ]; then
		echo "Usage: _exists cmd"
		return 1
	fi
	if type command >/dev/null 2>&1; then
		command -v $cmd >/dev/null 2>&1
	else
		type $cmd >/dev/null 2>&1
	fi
	ret="$?"
	return $ret
}
if [ -z "$BRANCH" ]; then
	BRANCH="master"
fi
if _exists curl; then
	curl https://raw.githubusercontent.com/a224327780/nq/$BRANCH/install.sh | sh -s $version $server $port $host "$@"
elif _exists wget; then
	wget -O - https://raw.githubusercontent.com/a224327780/nq/$BRANCH/install.sh | sh -s $version $server $port $host "$@"
else
	echo "Sorry, you must have curl or wget installed first." echo "Please install either of them and try again."
fi
