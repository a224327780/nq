#!/usr/bin/env sh

# Set environment
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Agent version
version="$(cat /etc/nodequery/version.txt)"

# Prepare values
prep() {
  echo "$1" | sed -e 's/^ *//g' -e 's/ *$//g' | sed -n '1 p'
}

# Base64 values
base() {
  echo "$1" | tr -d '\n' | base64 | tr -d '=' | tr -d '\n' | sed 's/\//%2F/g' | sed 's/\+/%2B/g'
}

# Integer values
int() {
  echo ${1/\.*/}
}

# Filter numeric
num() {
  case $1 in
  '' | *[!0-9\.]*) echo 0 ;;
  *) echo $1 ;;
  esac
}

# Agent version
version=$(prep "$version")

# System uptime
uptime=$(prep $(int "$(cat /proc/uptime | awk '{ print $1 }')"))

# Login session count
sessions=$(prep "$(who | wc -l)")

# Process count
processes=$(prep "$(ps axc | wc -l)")

# Process array
processes_array="$(ps axc -o uname:12,pcpu,rss,cmd --sort=-pcpu,-rss --noheaders --width 120)"
processes_array="$(echo "$processes_array" | grep -v " ps$" | sed 's/ \+ / /g' | sed '/^$/d' | tr "\n" ";")"

# OS details
os_kernel=$(prep "$(uname -r)")

if ls /etc/*release >/dev/null 2>&1; then
  os_name=$(prep "$(cat /etc/*release | grep '^PRETTY_NAME=\|^NAME=\|^DISTRIB_ID=' | awk -F\= '{ print $2 }' | tr -d '"' | tac)")
fi

if [ -z "$os_name" ]; then
  if [ -e /etc/redhat-release ]; then
    os_name=$(prep "$(cat /etc/redhat-release)")
  elif [ -e /etc/debian_version ]; then
    os_name=$(prep "Debian $(cat /etc/debian_version)")
  fi

  if [ -z "$os_name" ]; then
    os_name=$(prep "$(uname -s)")
  fi
fi

case $(uname -m) in
x86_64)
  os_arch=$(prep "x64")
  ;;
i*86)
  os_arch=$(prep "x86")
  ;;
*)
  os_arch=$(prep "$(uname -m)")
  ;;
esac

# CPU details
cpu_name=$(prep "$(cat /proc/cpuinfo | grep 'model name' | awk -F\: '{ print $2 }')")
cpu_cores=$(prep "$(($(cat /proc/cpuinfo | grep 'model name' | awk -F\: '{ print $2 }' | sed -e :a -e '$!N;s/\n/\|/;ta' | tr -cd \| | wc -c) + 1))")

if [ -z "$cpu_name" ]; then
  cpu_name=$(prep "$(cat /proc/cpuinfo | grep 'vendor_id' | awk -F\: '{ print $2 } END { if (!NR) print "N/A" }')")
  cpu_cores=$(prep "$(($(cat /proc/cpuinfo | grep 'processor' | awk -F\: '{ print $2 }' | sed -e :a -e '$!N;s/\n/\|/;ta' | tr -cd \| | wc -c) + 1))")
fi

cpu_freq=$(prep "$(cat /proc/cpuinfo | grep 'cpu MHz' | awk -F\: '{ print $2 }')")

if [ -z "$cpu_freq" ]; then
  cpu_freq=$(prep $(num "$(lscpu | grep 'CPU MHz' | awk -F\: '{ print $2 }' | sed -e 's/^ *//g' -e 's/ *$//g')"))
fi

# RAM usage
ram_total=$(prep $(num "$(cat /proc/meminfo | grep ^MemTotal: | awk '{ print $2 }')"))
ram_free=$(prep $(num "$(cat /proc/meminfo | grep ^MemFree: | awk '{ print $2 }')"))
ram_cached=$(prep $(num "$(cat /proc/meminfo | grep ^Cached: | awk '{ print $2 }')"))
ram_buffers=$(prep $(num "$(cat /proc/meminfo | grep ^Buffers: | awk '{ print $2 }')"))
ram_usage=$((($ram_total - ($ram_free + $ram_cached + $ram_buffers)) * 1024))
ram_total=$(($ram_total * 1024))

# Swap usage
swap_total=$(prep $(num "$(cat /proc/meminfo | grep ^SwapTotal: | awk '{ print $2 }')"))
swap_free=$(prep $(num "$(cat /proc/meminfo | grep ^SwapFree: | awk '{ print $2 }')"))
swap_usage=$((($swap_total - $swap_free) * 1024))
swap_total=$(($swap_total * 1024))

# Disk usage
disk_total=$(prep $(num "$(($(df -P -B 1 | grep '^/' | awk '{ print $2 }' | sed -e :a -e '$!N;s/\n/+/;ta')))"))
disk_usage=$(prep $(num "$(($(df -P -B 1 | grep '^/' | awk '{ print $3 }' | sed -e :a -e '$!N;s/\n/+/;ta')))"))

# Disk array
disk_array=$(prep "$(df -P -B 1 | grep '^/' | awk '{ print $1" "$2" "$3";" }' | sed -e :a -e '$!N;s/\n/ /;ta' | awk '{ print $0 } END { if (!NR) print "N/A" }')")

# Active connections
if [ -n "$(command -v ss)" ]; then
  connections=$(prep $(num "$(ss -tun | tail -n +2 | wc -l)"))
else
  connections=$(prep $(num "$(netstat -tun | tail -n +3 | wc -l)"))
fi

# Network interface
nic=$(prep "$(ip route get 8.8.8.8 | grep dev | awk -F'dev' '{ print $2 }' | awk '{ print $1 }')")

if [ -z $nic ]; then
  nic=$(prep "$(ip link show | grep 'eth[0-9]' | awk '{ print $2 }' | tr -d ':')")
fi

# IP addresses and network usage
#ipv4=$(prep "$(ip addr show $nic | grep 'inet ' | awk '{ print $2 }' | awk -F\/ '{ print $1 }' | grep -v '^127' | awk '{ print $0 } END { if (!NR) print "N/A" }')")
#ipv4=$(curl -s https://api.ipify.org/)
ipv6=$(prep "$(ip addr show $nic | grep 'inet6 ' | awk '{ print $2 }' | awk -F\/ '{ print $1 }' | grep -v '^::' | grep -v '^0000:' | grep -v '^fe80:' | awk '{ print $0 } END { if (!NR) print "N/A" }')")

old_recv=`cat /proc/net/dev | awk -F '[: ]+' '/'"$nic"'/{print $3}'`
old_sent=`cat /proc/net/dev | awk -F '[: ]+' '/'"$nic"'/{print $11}'`

sleep 2

recv=`cat /proc/net/dev | awk -F '[: ]+' '/'"$nic"'/{print $3}'`
sent=`cat /proc/net/dev | awk -F '[: ]+' '/'"$nic"'/{print $11}'`

rx=`echo $[($recv - $old_recv) / 1024]`
tx=`echo $[($sent - $old_sent) / 1024]`

# Average system load
load=$(prep "$(cat /proc/loadavg | awk '{ print $1" "$2" "$3 }')")

# Get network latency
# ping_eu=$(prep $(num "$(ping -c 2 -w 2 108.61.210.117 | grep rtt | cut -d'/' -f4 | awk '{ print $3 }')"))
# ping_us=$(prep $(num "$(ping -c 2 -w 2 108.61.219.200 | grep rtt | cut -d'/' -f4 | awk '{ print $3 }')"))
# ping_as=$(prep $(num "$(ping -c 2 -w 2 45.32.100.168 | grep rtt | cut -d'/' -f4 | awk '{ print $3 }')"))

# Build data for post
data_post="$version|$uptime|$sessions|$processes|$processes_array|$os_kernel|$os_name|$os_arch|$cpu_name|$cpu_cores|$cpu_freq|$ram_total|$ram_usage|$swap_total|$swap_usage|$disk_array|$disk_total|$disk_usage|$connections|$nic|$ipv4|$ipv6|$rx|$tx|$load"
echo $data_post

# Finished
exit 1
