#!/bin/bash
# files-08 setup: writes the read-only data files /srv/textlab/access.log
# (a web server log in Apache combined format) and
# /srv/textlab/accounts.csv. The log comes from a fixed seed, so every
# start gives the same file. The five busiest client addresses have
# fixed, distinct request counts, so the top 5 has no ties. Removes the
# reports of an earlier run and records the owner, the reports directory
# and the checksums of the data files. Prints nothing on success.
set -eu

LAB=files-08
DATA=/srv/textlab
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"

fail() {
	echo "Error: $*" >&2
	exit 1
}

# Task user: LAB_USER from labctl, else the first regular user
user="${LAB_USER:-student}"
if ! id "$user" &>/dev/null; then
	user=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 { print $1; exit }')
	[ -n "$user" ] || fail "no regular user found for the lab."
fi
home=$(getent passwd "$user" | cut -d: -f6)
[ -n "$home" ] && [ -d "$home" ] || fail "home directory of $user not found."
reports="$home/reports"

# Remove what an earlier run or the solution left behind
rm -rf "$DATA" "$reports"
mkdir -p "$DATA"

# Deterministic pseudo-random numbers: a linear congruential generator
# in 64-bit shell arithmetic. rnd <n> sets R to a number from 0 to n-1.
X=20261003
rnd() {
	X=$(((X * 1103515245 + 12345) & 2147483647))
	R=$(((X >> 16) % $1))
}

# Client addresses and their request counts. The first five are the top
# 5, with distinct counts; every other address has fewer requests.
ips=(
	203.0.113.45:214 198.51.100.7:187 192.0.2.10:163 203.0.113.9:139
	198.51.100.70:121 192.0.2.1:114 203.0.113.200:96 198.51.100.23:91
	192.0.2.100:88 203.0.113.4:83 198.51.100.150:77 192.0.2.77:74
	203.0.113.91:69 198.51.100.8:66 192.0.2.19:61 203.0.113.46:57
	198.51.100.71:52 192.0.2.101:49 203.0.113.12:44 198.51.100.200:41
	192.0.2.33:37 203.0.113.150:33 198.51.100.99:28 192.0.2.250:24
	203.0.113.5:19 198.51.100.3:15 192.0.2.66:11 203.0.113.88:8
	198.51.100.42:5 192.0.2.201:2
)
clients=()
for e in "${ips[@]}"; do
	for ((i = 0; i < ${e#*:}; i++)); do
		clients+=("${e%%:*}")
	done
done
# Fisher-Yates shuffle with the generator
for ((i = ${#clients[@]} - 1; i > 0; i--)); do
	rnd $((i + 1))
	tmp=${clients[i]}
	clients[i]=${clients[R]}
	clients[R]=$tmp
done

# Request paths with weight, status and base size. Status 404 has a
# body of 196 bytes. /robots.txt is 404 bytes long and answers 200.
# path weight status size
pathspec=(
	"/ 120 200 5120" "/index.html 60 200 5120" "/about.html 30 200 3311"
	"/About.html 6 404 196" "/contact.html 25 200 2875"
	"/css/site.css 90 200 14208" "/js/app.js 80 200 48211"
	"/js/app-v2.js 20 200 51034" "/js/app_v2.js 5 404 196"
	"/images/logo.png 85 200 20480" "/images/Logo.png 7 404 196"
	"/images/banner.jpg 40 200 183402" "/favicon.ico 70 200 1150"
	"/robots.txt 25 200 404" "/api/v1/items 55 200 2210"
	"/api/v1/items?page=2 20 200 2190" "/api/v1/Items 4 404 196"
	"/api/v1/status 30 200 64" "/search?q=linux 18 200 7340"
	"/search?q=rocky 12 200 7102" "/login 45 200 2310"
	"/logout 20 302 0" "/docs/README 10 200 8812"
	"/docs/readme.html 8 200 9930" "/downloads/rocky.iso 3 200 104857600"
	"/wp-login.php 22 404 196" "/.env 14 404 196"
	"/admin/config.php 9 404 196" "/server-status 6 403 199"
	"/old/page.html 11 404 196"
)
paths=() weights=() statuses=() sizes=()
total_weight=0
for e in "${pathspec[@]}"; do
	read -r p w s z <<<"$e"
	paths+=("$p")
	weights+=("$w")
	statuses+=("$s")
	sizes+=("$z")
	total_weight=$((total_weight + w))
done

agents=(
	"Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0"
	"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"
	"curl/7.61.1"
	"Wget/1.21.1"
	"python-requests/2.31.0"
)

t=0
{
	for client in "${clients[@]}"; do
		# Weighted choice of the path
		rnd "$total_weight"
		k=0
		while [ "$R" -ge "${weights[k]}" ]; do
			R=$((R - weights[k]))
			k=$((k + 1))
		done
		path=${paths[k]}
		status=${statuses[k]}
		size=${sizes[k]}

		method=GET
		rnd 20
		if [ "$path" = /login ] && [ "$R" -lt 8 ]; then
			method=POST
			status=302
			size=0
		elif [ "$R" -eq 0 ]; then
			method=HEAD
		fi

		# Sizes vary a little for dynamic pages; a 304 or HEAD has none
		bytes=$size
		case $path in
		/api/* | /search* | / | /index.html)
			rnd 200
			bytes=$((size + R))
			;;
		esac
		if [ "$status" = 200 ]; then
			rnd 12
			[ "$R" -eq 0 ] && status=304
		fi
		[ "$status" = 304 ] || [ "$method" = HEAD ] && bytes=-
		[ "$status" = 302 ] && bytes=-

		rnd 4
		auth=-
		[ "$R" -eq 0 ] && [ "$path" = /api/v1/items ] && auth=apiuser

		rnd 3
		ref=-
		[ "$R" -eq 0 ] && ref="http://www.example.com/"

		rnd ${#agents[@]}
		agent=${agents[R]}

		rnd 43
		t=$((t + R))
		[ "$t" -le 86399 ] || t=86399

		printf '%s - %s [03/Oct/2026:%02d:%02d:%02d +0000] "%s %s HTTP/1.1" %s %s "%s" "%s"\n' \
			"$client" "$auth" $((t / 3600)) $((t % 3600 / 60)) $((t % 60)) \
			"$method" "$path" "$status" "$bytes" "$ref" "$agent"
	done
} >"$DATA/access.log"

cat >"$DATA/accounts.csv" <<'CSV'
name,uid,dept,shell
adams,1004,ops,/bin/bash
baker,2210,dev,/bin/zsh
bashir,1532,sales,/bin/zsh
carter,987,ops,/sbin/nologin
diaz,10450,dev,/bin/bash
evans,1201,hr,/bin/sh
fischer,3075,dev,/bin/bash
garcia,1010,sales,/sbin/nologin
hall,20012,ops,/bin/bash
ito,1388,dev,/usr/bin/bash
jones,999,ops,/bin/bash
khan,4401,sales,/sbin/nologin
lee,1100,dev,/bin/bash
moreau,12001,hr,/bin/bash
novak,1502,ops,/bin/sh
olsen,2001,dev,/bin/bash
patel,1650,sales,/sbin/nologin
quinn,8800,ops,/bin/bash
rossi,1702,hr,/sbin/nologin
sato,1203,dev,/bin/zsh
tanaka,1999,dev,/bin/bash
ueda,30001,ops,/sbin/nologin
vargas,1305,sales,/bin/bash
weber,1450,dev,/usr/bin/bash
xu,2302,hr,/sbin/nologin
young,1001,ops,/bin/bash
zimmer,9100,dev,/bin/sh
abbott,1810,sales,/sbin/nologin
brooks,3300,ops,/bin/bash
chen,1102,dev,/bin/bash
dubois,5050,hr,/sbin/nologin
ellis,1260,ops,/bin/zsh
ford,10011,dev,/bin/bash
gray,1777,sales,/sbin/nologin
hughes,2525,ops,/bin/bash
ivanov,1601,dev,/sbin/nologin
jensen,7007,hr,/bin/bash
kowalski,1120,ops,/sbin/nologin
lopez,1003,dev,/bin/bash
morris,6200,sales,/sbin/nologin
CSV

chown root:root "$DATA" "$DATA/access.log" "$DATA/accounts.csv"
chmod 755 "$DATA"
chmod 444 "$DATA/access.log" "$DATA/accounts.csv"

# State: owner, reports directory, checksums of the data files
mkdir -p "$STATE_DIR"
{
	echo "$user"
	echo "$reports"
	(cd / && sha256sum "$DATA/access.log" "$DATA/accounts.csv")
} >"$STATE_FILE"
chmod 644 "$STATE_FILE"
