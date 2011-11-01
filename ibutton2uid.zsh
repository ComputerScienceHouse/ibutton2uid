#!/usr/bin/env zsh
emulate -L zsh
setopt err_exit
#setopt xtrace

# Note: The password file CANNOT have a newline at the end.
# Use xxd to check if it has one. The ascii code for newline is 0a
typeset -r PASSWORD_FILE="$PWD/password" USERNAME_FILE="$PWD/username"
if [[ ! -f "$PASSWORD_FILE" ]]; then
	printf "Password file %s not found\n" "$PASSWORD_FILE" >&2
	exit 1
fi
if [[ ! -f "$USERNAME_FILE" ]]; then
	printf "Username file %s not found\n" "$USERNAME_FILE" >&2
	exit 1
fi

typeset -r PIDFILE="$PWD/pid"
if [[ -f "$PIDFILE" ]]; then
	read -r pid < "$PIDFILE"
	if [[ -n "$pid" ]]; then
		kill -0 "$pid" 2>/dev/null && exit 0
	fi
fi

function unlock {
	zmodload -F zsh/files +b:rm
	rm -sf "$PIDFILE"
}

printf "%d\n" "$$" > "$PIDFILE"
trap 'unlock' EXIT ZERR HUP INT QUIT TERM

typeset -ri PORT=56123

function ldapsearch {
	command ldapsearch -H 'ldaps://ldap.csh.rit.edu' -y "$PASSWORD_FILE" -D "$(<$USERNAME_FILE)" -b 'ou=Users,dc=csh,dc=rit,dc=edu' -LLL "$@"
}

function ibutton2uid {
	typeset -a args
	ldapsearch "(ibutton=$1)" uid | \
	while read -rA args; do
		[[ -z "$args[*]" || "$args[1]" == dn: ]] && continue
		printf "%s\n" "$args[2]"
	done
	return 0
}

zmodload zsh/net/tcp

ztcp -l "$PORT"
typeset -i listenfd=$REPLY

while true; do
	# Blocking here will cause zsh to be unable to cleanup the last child created until a new connection is made.
	# This is OK with me because there will never be more than one zombie (once a connection comes in, zsh will cleanup the old zombie (and make a new one))
	ztcp -a $listenfd
	typeset -i connfd=$REPLY
	(
		trap 'ztcp -c $connfd' EXIT ZERR HUP INT QUIT TERM
		typeset ibutton
		read -r ibutton
		[[ -z "$ibutton" || ! "$ibutton" =~ ^[A-Z0-9]+$ ]] && exit 1
		ibutton2uid "$ibutton"
	) <&$connfd >&$connfd &
	ztcp -c $connfd
done
