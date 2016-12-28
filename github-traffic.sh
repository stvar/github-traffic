#!/bin/bash

# Copyright (C) 2016  Stefan Vargyas
# 
# This file is part of Github-Traffic.
# 
# Github-Traffic is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# Github-Traffic is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with Github-Traffic.  If not, see <http://www.gnu.org/licenses/>.

usage()
{
    echo "usage: $1 [$(sed 's/^://;s/-:$/\x0/;s/[^:]/|-\0/g;s/:/ <arg>/g;s/^|//;s/\x0/-<long>/' <<< "$2")]"
}

quote()
{
    local __n__
    local __v__

    [ -z "$1" -o "$1" == "__n__" -o "$1" == "__v__" ] &&
    return 1

    printf -v __n__ '%q' "$1"
    eval __v__="\"\$$__n__\""
    #!!! echo "!!! 0 __v__='$__v__'"
    test -z "$__v__" && return 0
    printf -v __v__ '%q' "$__v__"
    #!!! echo "!!! 1 __v__='$__v__'"
    printf -v __v__ '%q' "$__v__"  # double quote
    #!!! echo "!!! 2 __v__='$__v__'"
    test -z "$SHELL_BASH_QUOTE_TILDE" &&
    __v__="${__v__//\~/\\~}"
    eval "$__n__=$__v__"
}

quote2()
{
    local __n__
    local __v__

    local __q__='q'
    [ "$1" == '-i' ] && {
        __q__=''
        shift
    }

    [ -z "$1" -o "$1" == "__n__" -o "$1" == "__v__" -o "$1" == "__q__" ] &&
    return 1

    printf -v __n__ '%q' "$1"
    eval __v__="\"\$$__n__\""
    __v__="$(sed -nr '
        H
        $!b
        g
        s/^\n//
        s/\x27/\0\\\0\0/g'${__q__:+'
        s/^/\x27/
        s/$/\x27/'}'
        p
    ' <<< "$__v__")"
    test -n "$__v__" &&
    printf -v __v__ '%q' "$__v__"
    eval "$__n__=$__v__"
}

optopt()
{
    local __n__="${1:-$opt}"       #!!!NONLOCAL
    local __v__=''
    test -n "$__n__" &&
    printf -v __v__ '%q' "$__n__"  # paranoia
    test -z "$SHELL_BASH_QUOTE_TILDE" &&
    __v__="${__v__//\~/\\~}"
    eval "$__n__=$__v__"
}

optarg()
{
    local __n__="${1:-$opt}"       #!!!NONLOCAL
    local __v__=''
    test -n "$OPTARG" &&
    printf -v __v__ '%q' "$OPTARG" #!!!NONLOCAL
    test -z "$SHELL_BASH_QUOTE_TILDE" &&
    __v__="${__v__//\~/\\~}"
    eval "$__n__=$__v__"
}

optact()
{
    local __v__="${1:-$opt}"       #!!!NONLOCAL
    printf -v __v__ '%q' "$__v__"  # paranoia
    test -z "$SHELL_BASH_QUOTE_TILDE" &&
    __v__="${__v__//\~/\\~}"
    eval "act=$__v__"
}

optlong()
{
    local a="$1"

    if [ "$a" == '-' ]; then
        if [ -z "$OPT" ]; then                                      #!!!NONLOCAL
            local A="${OPTARG%%=*}"                                 #!!!NONLOCAL
            OPT="-$opt$A"                                           #!!!NONLOCAL
            OPTN="${OPTARG:$((${#A})):1}"                           #!!!NONLOCAL
            OPTARG="${OPTARG:$((${#A} + 1))}"                       #!!!NONLOCAL
        else
            OPT="--$OPT"                                            #!!!NONLOCAL
        fi
    elif [ "$opt" == '-' -o \( -n "$a" -a -z "$OPT" \) ]; then      #!!!NONLOCAL
        OPT="${OPTARG%%=*}"                                         #!!!NONLOCAL
        OPTN="${OPTARG:$((${#OPT})):1}"                             #!!!NONLOCAL
        OPTARG="${OPTARG:$((${#OPT} + 1))}"                         #!!!NONLOCAL
        [ -n "$a" ] && OPT="$a-$OPT"                                #!!!NONLOCAL
    elif [ -z "$a" ]; then                                          #!!!NONLOCAL
        OPT=''                                                      #!!!NONLOCAL
        OPTN=''                                                     #!!!NONLOCAL
    fi
}

optlongchkarg()
{
    test -z "$OPT" &&                               #!!!NONLOCAL
    return 0

    [[ "$opt" == [a-zA-Z] ]] || {                   #!!!NONLOCAL
        error "internal: invalid opt name '$opt'"   #!!!NONLOCAL
        return 1
    }

    local r="^:[^$opt]*$opt(.)"
    [[ "$opts" =~ $r ]]
    local m="$?"

    local s
    if [ "$m" -eq 0 ]; then
        s="${BASH_REMATCH[1]}"
    elif [ "$m" -eq 1 ]; then
        error "internal: opt '$opt' not in '$opts'" #!!!NONLOCAL
        return 1
    elif [ "$m" -eq "2" ]; then
        error "internal: invalid regex: $r"
        return 1
    else
        error "internal: unexpected regex match result: $m: ${BASH_REMATCH[@]}"
        return 1
    fi

    if [ "$s" == ':' ]; then
        test -z "$OPTN" && {                        #!!!NONLOCAL
            error --long -a
            return 1
        }
    else
        test -n "$OPTN" && {                        #!!!NONLOCAL
            error --long -d
            return 1
        }
    fi
    return 0
}

error()
{
    local __self__="$self"     #!!!NONLOCAL
    local __help__="$help"     #!!!NONLOCAL
    local __OPTARG__="$OPTARG" #!!!NONLOCAL
    local __opts__="$opts"     #!!!NONLOCAL
    local __opt__="$opt"       #!!!NONLOCAL
    local __OPT__="$OPT"       #!!!NONLOCAL

    local self="error"

    # actions: \
    #  a:argument for option -$OPTARG not found|
    #  o:when $OPTARG != '?': invalid command line option -$OPTARG, or, \
    #    otherwise, usage|
    #  i:invalid argument '$OPTARG' for option -$opt|
    #  d:option '$OPTARG' does not take arguments|
    #  e:error message|
    #  w:warning message|
    #  u:unexpected option -$opt|
    #  g:when $opt == ':': equivalent with 'a', \
    #    when $opt == '?': equivalent with 'o', \
    #    when $opt is anything else: equivalent with 'u'

    local act="e"
    local A="$__OPTARG__" # $OPTARG
    local h="$__help__"   # $help
    local m=""            # error msg
    local O="$__opts__"   # $opts
    local P="$__opt__"    # $opt
    local L="$__OPT__"    # $OPT
    local S="$__self__"   # $self

    local long=''         # short/long opts (default)

    #!!! echo "!!! A='$A'"
    #!!! echo "!!! O='$O'"
    #!!! echo "!!! P='$P'"
    #!!! echo "!!! L='$L'"
    #!!! echo "!!! S='$S'"

    local opt
    local opts=":aA:degh:iL:m:oO:P:S:uw-:"
    local OPTARG
    local OPTERR=0
    local OPTIND=1
    while getopts "$opts" opt; do
        case "$opt" in
            [adeiouwg])
                act="$opt"
                ;;
            #[])
            #	optopt
            #	;;
            [AhLmOPS])
                optarg
                ;;
            \:)	echo "$self: error: argument for option -$OPTARG not found" >&2
                return 1
                ;;
            \?)	if [ "$OPTARG" != "?" ]; then
                    echo "$self: error: invalid command line option -$OPTARG" >&2
                else
                    echo "$self: $(usage $self $opts)"
                fi
                return 1
                ;;
            -)	case "$OPTARG" in
                    long|long-opts)
                        long='l' ;;
                    short|short-opts)
                        long='' ;;
                    *)	echo "$self: error: invalid command line option --$OPTARG" >&2
                        return 1
                        ;;
                esac
                ;;
            *)	echo "$self: error: unexpected option -$OPTARG" >&2
                return 1
                ;;
        esac
    done
    #!!! echo "!!! A='$A'"
    #!!! echo "!!! O='$O'"
    #!!! echo "!!! P='$P'"
    #!!! echo "!!! L='$L'"
    #!!! echo "!!! S='$S'"
    shift $((OPTIND - 1))
    test -n "$1" && m="$1"
    local f="2"
    if [ "$act" == "g" ]; then
        if [ "$P" == ":" ]; then
            act="a"
        elif [ "$P" == "?" ]; then
            act="o"
        else 
            act="u"
        fi
    fi
    local o=''
    if [ -n "$long" -a -n "$L" ]; then
        test "${L:0:1}" != '-' && o+='--'
        o+="$L"
    elif [[ "$act" == [aod] ]]; then
        o="-$A"
    elif [[ "$act" == [iu] ]]; then
        o="-$P"
    fi
    case "$act" in
        a)	m="argument for option $o not found"
            ;;
        o)	if [ "$A" != "?" ]; then
                m="invalid command line option $o"
            else
                act="h"
                m="$(usage $S $O)"
                f="1"
            fi
            ;;
        i)	m="invalid argument for $o: '$A'"
            ;;
        u)	m="unexpected option $o"
            ;;
        d)	m="option $o does not take arguments"
            ;;
        *)	# [ew]
            if [ "$#" -ge "2" ]; then
                S="$1"
                m="$2"
            elif [ "$#" -ge "1" ]; then
                m="$1"
            fi
            ;;
    esac
    if [ "$act" == "w" ]; then
        m="warning${m:+: $m}"
    elif [ "$act" != "h" ]; then
        m="error${m:+: $m}"
    fi
    if [ -z "$S" -o "$S" == "-" ]; then
        printf "%s\n" "$m" >&$f
    else
        printf "%s: %s\n" "$S" "$m" >&$f
    fi
    if [ "$act" == "h" ]; then
        test -n "$1" && h="$1"
        test -n "$h" &&
        printf "%s\n" "$h" >&$f
    fi
    return $f
}

github-traffic()
{
    local self="github-traffic"
    local outx='raw|echo|pretty|terse|json2'
    local home="."

    local x="eval"
    local act="C"       # actions: \
                        #  C: clones (default) (--clones)|
                        #  P: paths (--paths)|
                        #  R: referrers (--referrers)|
                        #  V: views (--views)
    local e="+"         # pass `-e|--error-context-size=NUM' to json (default: json's default: 32) (--error-context=NUM)
    local h="+"         # home dir (default: current directory) (--home=DIR)
    local o="+"         # output type: 'raw', 'echo', 'pretty', 'terse' or 'json2' (default: 'json2') (--output=TYPE|--raw|--echo|--pretty|--terse|--json2)
    local r=""          # repository name (--repo[sitory]=STR)
    local u="+"         # user and password to pass to curl (--user=STR)
    local v=""          # pass `-v|--verbose' to curl (otherwise pass `--silent --show-error') (--verbose)

    local opt
    local OPT
    local OPTN
    local opts=":dCe:h:o:PRr:u:vVx-:"
    local OPTARG
    local OPTERR=0
    local OPTIND=1
    while getopts "$opts" opt; do
        # discriminate long options
        optlong

        # translate long options to short ones
        test -n "$OPT" &&
        case "$OPT" in
            clones)
                opt='C' ;;
            error-context)
                opt='e' ;;
            home)
                opt='h' ;;
            @(output|$outx))
                opt='o' ;;
            repo|repository)
                opt='r' ;;
            paths)
                opt='P' ;;
            referrers)
                opt='R' ;;
            user)
                opt='u' ;;
            verbose)
                opt='v' ;;
            views)
                opt='V' ;;
            *)	error --long -o
                return 1
                ;;
        esac

        # check long option argument
        [[ "$opt" == [o] ]] ||
        optlongchkarg ||
        return 1

        # handle short options
        case "$opt" in
            d)	x="echo"
                ;;
            x)	x="eval"
                ;;
            [CPRV])
                optact
                ;;
            [v])
                optopt
                ;;
            [hru])
                optarg
                ;;
            e)	[[ "$OPTARG" == @(+|+([0-9])) ]] || {
                    error --long -i
                    return 1
                }
                optarg
                ;;
            o)	[[ -n "$OPT" || "${OPTARG%%=*}" == @(output|$outx) ]] || {
                    error -i
                    return 1
                }
                optlong -

                case "${OPT:2}" in
                    output)
                        [ -n "$OPTN" ] || {
                            error --long -a
                            return 1
                        }
                        [[ "$OPTARG" == @(+|$outx) ]] || {
                            error --long -i
                            return 1
                        }
                        o="$OPTARG"
                        ;;
                    @($outx))
                        [ -z "$OPTN" ] || {
                            error --long -d
                            return 1
                        }
                        o="${OPT:2}"
                        ;;
                    *)	error --long -o
                        return 1
                        ;;
                esac
                ;;
            *)	error --long -g
                return 1
                ;;
        esac
    done
    shift $((OPTIND - 1))

    [ -z "$r" ] && {
        error "repository name not given"
        return 1
    }

    [ -z "$u" ] && {
        error "user/pass cannot be null"
        return 1
    }

    [ "$e" == '+' ] && e=''

    [ "$h" == '+' ] && h="$home"
    [ "$h" == '.' ] && h=''

    [ -n "$h" ] && {
        h="${h%%+(/)}"
        [ -z "$h" ] &&
        h='/'
    }
    [ -n "$h" -a ! -d "$h" ] && {
        error "home dir '$h' not found"
        return 1
    }

    [ "$o" == '+' ] && o='json2'

    [ "$u" == '+' ] && u="$GITHUB_USER"
    [ "$u" == '-' ] && u=''

    local t=''
    [ "$o" != 'raw' ] && {
        [[ -z "$h" || "$h" =~ /$ ]] || h+='/'
        t="${h:-./}$self.so"
        [ ! -f "$t" ] &&
        t="$h$self.json"
        [ ! -f "$t" ] && {
            error "json type-lib '$t' not found"
            return  1
        }
    }

    local T
    case "$act" in
        C)	T='clones'
            ;;
        P)	T='paths'
            ;;
        R)	T='referrers'
            ;;
        V)	T='views'
            ;;
        *)	error "internal: unexpected act='$act' [0]"
            return 1
            ;;
    esac

    case "$o" in
        raw)
            o=''
            ;;
        echo)
            o='E'
            ;;
        pretty)
            o='P'
            ;;
        terse)
            o='R'
            ;;
        json2)
            o='J'
            ;;
        *)	error "internal: unexpected o='$o'"
            return 1
            ;;
    esac

    # stev: API doc:   https://developer.github.com/v3/repos/traffic/
    # stev: blog post: https://developer.github.com/changes/2016-08-15-traffic-api-preview/

    local E
    [[ "$act" == [PR] ]] &&
    E="popular/$T" ||
    E="$T"

    local U="https://api.github.com/repos${u:+/${u%%:*}}/$r/traffic/$E"
    local H='Accept: application/vnd.github.spiderman-preview'

    quote h
    quote u
    quote U
    quote2 H
    quote T

    local c="\
curl"
    [ -z "$v" ] && c+=" \\
--silent --show-error"
    [ -n "$v" ] && c+=" \\
--verbose"
    [ -n "$u" ] && c+=" \\
--user $u"
    [ -n "$H" ] && c+=" \\
--header $H"
    c+=" \\
$U"
    [ -n "$o" ] && c+="|
json ${t:+-t $t:$T }-${o}V${e:+ -e $e}"

    $x "$c"
}

