#!/bin/bash
# Package Management Lab 05: Cleanup
#
# Removes what "make install" of joe 4.6 writes, for both
#   ./configure --prefix=/usr --sysconfdir=/etc   (the lab's target)
#   ./configure                                   (default prefix /usr/local)
#   ./configure --prefix=/usr                     (sysconfdir ends up in /usr/etc)
# Only joe's own files and joe-only directories are listed. A path is
# removed only if no RPM package owns it, so the joe RPM (or any other
# package) is never damaged. Shared directories (/usr/bin, /usr/share,
# /usr/share/man/man1, /etc, ...) are never removed.
# Compilers and build tools are left installed.

BIN="jmacs joe jpico jstar rjoe"
DESKTOP="jmacs.desktop joe.desktop jpico.desktop jstar.desktop"
DOCS="ChangeLog NEWS.md README.md README.old hacking.md man.md"
ETCFILES="ftyperc jicerc.ru jmacsrc joerc joerc.zh_TW jpicorc jstarrc rjoerc
    shell.csh shell.sh"
CHARMAPS="klingon"
COLORS="default.jcf gruvbox.jcf ir_black.jcf molokai.jcf solarized.jcf
    wombat.jcf xoria.jcf zenburn-hc.jcf zenburn.jcf"
LANGS="de.po fr.po ru.po uk.po zh_TW.po"
SYNTAX="4gl.jsf ada.jsf ant.jsf asm.jsf avr.jsf awk.jsf batch.jsf c.jsf
    clojure.jsf cobol.jsf coffee.jsf comment_todo.jsf conf.jsf
    context.jsf csh.jsf csharp.jsf css.jsf d.jsf debian.jsf diff.jsf
    dockerfile.jsf elixir.jsf erb.jsf erlang.jsf filename.jsf
    fortran.jsf git-commit.jsf go.jsf groovy.jsf haml.jsf haskell.jsf
    html.jsf htmlerb.jsf ini.jsf iptables.jsf java.jsf jcf.jsf
    joerc.jsf js.jsf jsf_check.jsf jsf.jsf json.jsf lisp.jsf lua.jsf
    m4.jsf mail.jsf mason.jsf matlab.jsf md.jsf ocaml.jsf pascal.jsf
    perl.jsf php.jsf powershell.jsf prolog.jsf properties.jsf ps.jsf
    puppet.jsf python.jsf r.jsf rexx.jsf ruby.jsf rust.jsf scala.jsf
    sed.jsf sh.jsf sieve.jsf skill.jsf sml.jsf spec.jsf sql.jsf
    swift.jsf tcl.jsf tex.jsf troff.jsf typescript.jsf verilog.jsf
    vhdl.jsf whitespace.jsf xml.jsf yaml.jsf"

owned() { rpm -qf -- "$1" &>/dev/null; }

rm_file() {
	local p="$1"
	[ -e "$p" ] || [ -L "$p" ] || return 0
	[ -d "$p" ] && [ ! -L "$p" ] && return 0
	owned "$p" && return 0
	rm -f -- "$p"
}

rm_dir() {
	local p="$1"
	[ -d "$p" ] && [ ! -L "$p" ] || return 0
	owned "$p" && return 0
	rmdir -- "$p" 2>/dev/null
	return 0
}

# remove_install <prefix> <sysconfdir>
remove_install() {
	local P="$1" E="$2" f
	for f in $BIN; do rm_file "$P/bin/$f"; done
	for f in $DESKTOP; do rm_file "$P/share/applications/$f"; done
	for f in $DOCS; do rm_file "$P/share/doc/joe/$f"; done
	for f in $CHARMAPS; do rm_file "$P/share/joe/charmaps/$f"; done
	for f in $COLORS; do rm_file "$P/share/joe/colors/$f"; done
	for f in $LANGS; do rm_file "$P/share/joe/lang/$f"; done
	for f in $SYNTAX; do rm_file "$P/share/joe/syntax/$f"; done
	rm_file "$P/share/man/man1/joe.1"
	rm_file "$P/share/man/ru/man1/joe.1"
	for f in $ETCFILES; do rm_file "$E/joe/$f"; done
	# joe-only directories, deepest first; rmdir fails if not empty
	for f in charmaps colors lang syntax; do rm_dir "$P/share/joe/$f"; done
	rm_dir "$P/share/joe"
	rm_dir "$P/share/doc/joe"
	rm_dir "$P/share/man/ru/man1"
	rm_dir "$P/share/man/ru"
	rm_dir "$E/joe"
}

# Both prefixes, each with its default sysconfdir (PREFIX/etc, what a
# configure without --sysconfdir gives) and with /etc
for P in /usr /usr/local; do
	remove_install "$P" "$P/etc"
	remove_install "$P" /etc
done
rm_dir /usr/etc

# Leftover source tree and tarball, top level only
LABUSER="${SUDO_USER:-student}"
LABHOME=$(getent passwd "$LABUSER" | cut -d: -f6)
for d in /tmp /root "$LABHOME"; do
	[ -n "$d" ] && [ -d "$d" ] || continue
	rm -f -- "$d/joe-4.6.tar.gz"
	if [ -d "$d/joe-4.6" ] && [ ! -L "$d/joe-4.6" ] && [ -f "$d/joe-4.6/joe/main.c" ]; then
		rm -rf -- "$d/joe-4.6"
	fi
done

echo "Cleanup complete. Compiler and build tools remain installed."
exit 0
