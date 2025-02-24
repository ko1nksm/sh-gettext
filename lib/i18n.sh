# shellcheck shell=sh

: "${I18N_PRINTF:=}"
: "${I18N_GETTEXT:=gettext}" "${I18N_NGETTEXT:=ngettext}"
I18N_DECIMALPOINT='.' I18N_LF='
'

i18n_setup_gettext() {
  i18n_work="${TEXTDOMAIN+x}${TEXTDOMAIN:-}"
  TEXTDOMAIN='-'

  # Fallback when gettext is not available
  i18n__native_gettext() { i18n__put "$1"; }
  i18n__native_pgettext() { i18n__put "$2"; }

  if type "$I18N_GETTEXT" >/dev/null 2>&1; then
    # gettext is available
    if "$I18N_GETTEXT" -E '' >/dev/null 2>&1; then
      # Probably GNU gettext or POSIX gettext.
      i18n__native_gettext() {
        "$I18N_GETTEXT" -E ${2+-c "$2"} "$1"
      }
    else
      # Implementation without -E option.
      # Probably Solaris 10/11.
      i18n__native_gettext() {
        i18n__replace_all i18n_work "$1" "\\" "\\\\"
        set -- "$i18n_work"
        unset i18n_work
        # Workaround for Solaris/OpenIndiana
        # gettext returns exit status 1 if TEXTDOMAIN is empty
        TEXTDOMAIN="${TEXTDOMAIN:--}" "$I18N_GETTEXT" -e ${2+-c "$2"} "$1"
      }
    fi

    if "$I18N_GETTEXT" -c '' '' >/dev/null 2>&1; then
      i18n__native_pgettext() { i18n__native_gettext "$2" "$1"; }
    fi
  fi

  # Fallback when ngettext is not available
  i18n__native_ngettext() {
    [ "$3" = '1' ] || shift
    i18n__put "$1"
  }
  i18n__native_npgettext() { shift && i18n__native_ngettext "$@"; }

  if type "$I18N_NGETTEXT" >/dev/null 2>&1; then
    # ngettext is available
    i18n__native_ngettext() {
      "$I18N_NGETTEXT" -E ${4+-c "$4"} "$1" "$2" "$3"
    }

    if "$I18N_NGETTEXT" -c '' '' '' '' >/dev/null 2>&1; then
      i18n__native_npgettext() { i18n__native_ngettext "$2" "$3" "$4" "$1"; }
    fi
  fi

  case $i18n_work in
    ?) TEXTDOMAIN=${i18n_work#x} ;;
    *) unset TEXTDOMAIN ;;
  esac
}
i18n_setup_gettext

i18n_build_array() {
  I18N_ARRAY_NAME=$1
}

i18n_gettext_noop() {
  i18n__put "$1"
}

i18n_gettext_s2v() {
  eval "$1=\"\$2\""
}

i18n_gettext_a2v() {
  set -- "$I18N_ARRAY_NAME" "$1"
  i18n__replace_all i18n_work "$2" "'" "'\''"
  eval "$1=\"\$$1 '\$i18n_work'\""
  unset i18n_work
}

i18n_gettext_a2a() {
  set -- "$I18N_ARRAY_NAME" "$1"
  eval "$1=(\${$1[@]+\"\${$1[@]}\"} \"\$2\")"
}

i18n_gettext_a2aa() {
  set -- "$I18N_ARRAY_NAME" "$1" "$2"
  eval "${1}[\"\$2\"]=\"\$3\""
}

i18n_setup_printf() {
  if [ "${KSH_VERSION:-}" ]; then
    i18n__put() {
      IFS=" $IFS" && set -- "$*" && IFS=${IFS# }
      print -nr -- "${1:-}"
    }

    i18n__putln() {
      IFS=" $IFS" && set -- "$*" && IFS=${IFS# }
      print -r -- "${1:-}"
    }
  else
    i18n__put() {
      IFS=" $IFS" && set -- "$*" && IFS=${IFS# }
      printf '%s' "${1:-}"
    }

    i18n__putln() {
      IFS=" $IFS" && set -- "$*" && IFS=${IFS# }
      printf '%s\n' "${1:-}"
    }
  fi

  if [ "$(printf -- x)" = 'x' ]; then
    # shellcheck disable=SC2059
    i18n__native_printf() { printf -- "$@"; }
  else
    # shellcheck disable=SC2059
    i18n__native_printf() { printf "$@"; }
  fi

  i18n__printf() {
   "${I18N_PRINTF:-i18n__native_printf}" "$@"
  }

  if [ "$(i18n__printf "%'d" 0 2>/dev/null)" = 0 ]; then
    i18n__printf_is_decimal_separator_supported() { true; }
  else
    i18n__printf_is_decimal_separator_supported() { false; }
  fi
}
i18n_setup_printf

i18n_detect_decimal_point() {
  set -- "$(printf "%1.1f" 1)" 2>/dev/null
  I18N_DECIMALPOINT=${1:-1.0}
  I18N_DECIMALPOINT=${I18N_DECIMALPOINT#1}
  I18N_DECIMALPOINT=${I18N_DECIMALPOINT%0}

  # Workaround for GNU printf <= 8.30
  #   It outputs a locale-dependent decimal point symbol,
  #   but cannot parse with a locale-dependent decimal point symbol.
  if ! printf "%f" "1${I18N_DECIMALPOINT}2" >/dev/null 2>&1; then
    I18N_DECIMALPOINT='.'
  fi
}
i18n_detect_decimal_point

i18n__gettext() {
  i18n_work=$(i18n__native_gettext "$2" && echo x)
  set -- "$1" "${i18n_work%x}"
  unset i18n_work
  eval "$1=\$2"
}

i18n__ngettext() {
  i18n_work=$(i18n__native_ngettext "$2" "$3" "$4" && echo x)
  set -- "$1" "${i18n_work%x}"
  unset i18n_work
  eval "$1=\$2"
}

i18n__sgettext() {
  i18n_work=$(i18n__native_gettext "$2" && echo x)
  set -- "$1" "$2" "${i18n_work%x}"
  unset i18n_work
  [ "$2" = "$3" ] && set -- "$1" "$2" "${3#*|}"
  eval "$1=\$3"
}

i18n__nsgettext() {
  i18n_work=$(i18n__native_ngettext "$2" "$3" "$4" && echo x)
  set -- "$1" "$2" "$3" "$4" "${i18n_work%x}"
  unset i18n_work
  [ "$2" = "$5" ] && set -- "$1" "$2" "$3" "$4" "${5#*|}"
  eval "$1=\$5"
}

i18n__pgettext() {
  i18n_work=$(i18n__native_pgettext "$2" "$3" && echo x)
  set -- "$1" "${i18n_work%x}"
  unset i18n_work
  eval "$1=\$2"
}

i18n__npgettext() {
  i18n_work=$(i18n__native_npgettext "$2" "$3" "$4" "$5" && echo x)
  set -- "$1" "${i18n_work%x}"
  unset i18n_work
  eval "$1=\$2"
}

# shellcheck disable=SC3003
i18n__generate_gettext_apis() {
  args() {
    set -- "$1" "$2:" 1
    while [ "$2" ]; do
      set -- "$1 \"\$$3\"" "${2#*:}" $(($3 + 1))
    done
    i18n__putln "$1"
  }

  if [ $':' = '$:' ]; then
    # For shells not supporting $'...'
    # shellcheck disable=SC2016
    make() {
      i18n__putln "$1() {"
      args '  set --' "$2"
      set -- "$1" "$2:"
      while [ "$2" ]; do
        set -- "$1" "${2#*:}" "${2%%:*}"
        case $3 in (MSGID)
          i18n__putln '  case $1 in (\$*)'
          i18n__putln '    i18n__unescape i18n_work "${1#\$}"'
          i18n__putln '    shift'
          i18n__putln '    set -- "$i18n_work" "$@"'
          i18n__putln '    unset i18n_work'
          i18n__putln '  esac'
        esac
        i18n__putln '  set -- "$@" "$1" && shift'
      done
      i18n__putln "  i18n__${1#*_} \"\$@\""
      i18n__putln '}'
    }
  else
    # For shells supporting $'...'
    make() {
      i18n__putln "$1() {"
      args "  i18n__${1#*_}" "$2"
      i18n__putln '}'
    }
  fi

  # i18n_gettext VARNAME MSGID
  make i18n_gettext VARNAME:MSGID
  # i18n_ngettext VARNAME MSGID MSGID-PLURAL N
  make i18n_ngettext VARNAME:MSGID:MSGID:N
  # i18n_sgettext VARNAME MSGID
  make i18n_sgettext VARNAME:MSGID
  # i18n_nsgettext VARNAME MSGID MSGID-PLURAL N
  make i18n_nsgettext VARNAME:MSGID:MSGID:N
  # i18n_pgettext VARNAME MSGCTXT MSGID
  make i18n_pgettext VARNAME:MSGCTXT:MSGID
  # i18n_npgettext VARNAME MSGCTXT MSGID MSGID-PLURAL N
  make i18n_npgettext VARNAME:MSGCTXT:MSGID:MSGID:N
}
eval "$(i18n__generate_gettext_apis)"

# shellcheck disable=SC2016
i18n__generate_unescape() {
  printf '%s\n' \
    'i18n__unescape() {' \
    '  set -- "$1" "$2\\" ""' \
    '  while set -- "$1" "${2#*\\}" "${3}${2%%\\*}" && [ "$2" ]; do' \
    '    case $2 in'

  set -- n \\0012 t \\0011 r \\0015 a \\0007 b \\0010 f \\0014 v \\0013
  printf '      %s*) set -- "$1" "${2#?}" "${3}%b" ;;\n' \\\\ '\0134\0134' "$@"

  set -- && i=0
  while [ "$i" -lt 127 ] && i=$((i + 1)); do
    j=$((i / 64))$(((i % 64) / 8))$((i % 8))
    case $j in
      042 | 044 | 134 | 140) set -- "$@" "$j" "\\\\\\0$j" ;;
      *) set -- "$@" "$j" "\\0$j" ;;
    esac
  done
  printf '      %s*) set -- "$1" "${2#???}" "${3}%b" ;;\n' "$@"

  set -- && i=0
  while [ "$i" -lt 63 ] && i=$((i + 1)); do
    j=$(((i % 64) / 8))$((i % 8))
    case $j in
      42 | 44) set -- "$@" "$j" "\\\\\\0$j" ;;
      *) set -- "$@" "$j" "\\0$j" ;;
    esac
  done
  printf '      %s*) set -- "$1" "${2#??}" "${3}%b" ;;\n' "$@"

  set -- 1 \\0001 2 \\0002 3 \\0003 4 \\0004 5 \\0005 6 \\0006 7 \\0007
  printf '      %s*) set -- "$1" "${2#?}" "${3}%b" ;;\n' "$@"

  printf '%s\n' \
    '      *) set -- "$1" "${2#?}" "${3}\\${2%"${2#?}"}" ;;' \
    '    esac' \
    '  done' \
    '  eval "$1=\$3"' \
    '}'
}
eval "$(i18n__generate_unescape)"

if (eval ": \"\${PPID//?/}\"") 2>/dev/null; then
  # Not POSIX shell compliant but fast
  i18n__replace_all() {
    eval "$1=\${2//\"\$3\"/\"\$4\"}"
  }
else
  # For POSIX Shells
  i18n__replace_all() {
    set -- "$1" "$2$3" "$3" "$4" ""
    while [ "$2" ]; do
      set -- "$1" "${2#*"$3"}" "$3" "$4" "$5${2%%"$3"*}$4"
    done
    eval "$1=\${5%\"\$4\"}"
  }
fi

# i18n_printf FORMAT [ARGUMENT]...
i18n_printf() {
  i18n__replace_all i18n_work "$1" "\\" "\\\\"
  i18n__printf_args_reorder i18n_work "$i18n_work" $(($# - 1))
  eval "shift; set -- \"\${i18n_work%@*}\" ${i18n_work##*@}"
  i18n__printf_format_manipulater i18n_work "${i18n_work%@*}"
  shift
  set -- "$@" "${i18n_work%@*}"
  i18n_work=${i18n_work##*@}
  while [ "$i18n_work" ]; do
    case $i18n_work in
      +*)
        case $1 in
          # Arabic Decimal Separator U+066B (UTF-8: 0xD9 0xAB)
          *٫*) set -- "$@" "${1%%٫*}$I18N_DECIMALPOINT${1#*٫}" ;;
          *,*) set -- "$@" "${1%%,*}$I18N_DECIMALPOINT${1#*,}" ;;
          *.*) set -- "$@" "${1%%.*}$I18N_DECIMALPOINT${1#*.}" ;;
          *) set -- "$@" "$1" ;;
        esac
        ;;
      *) set -- "$@" "$1" ;;
    esac
    shift
    i18n_work=${i18n_work#* }
  done
  unset i18n_work
  i18n__printf "$@"
}

# i18n_printfln FORMAT [ARGUMENT]...
i18n_printfln() {
  i18n_work="${1}${I18N_LF}"
  shift
  set -- "$i18n_work" "$@"
  unset i18n_work
  i18n_printf "$@"
}

i18n__printf_args_reorder() {
  set -- "$1" "$2%" "$3" '' '' 1
  while [ "$2" ]; do
    set -- "$1" "${2#*\%}" "$3" "$4${2%%\%*}%" "$5" "$6"
    case $2 in
      '') continue ;;
      %*) set -- "$1" "${2#%}" "$3" "$4%" "$5" "$6" && continue ;;
    esac

    if i18n__printf_format_is_parameter_field i18n_work "$2"; then
      set -- "$1" "${2#*\$}" "$3" "$4" "$5" "$6" "$i18n_work"
      set -- "$@" $((${7#"${7%%[!0]*}"}+0))
      if [ 1 -le "$8" ] && [ "$8" -le "$3" ]; then
        set -- "$1" "$2" "$3" "$4" "$5 \"\${$8}\"" "$6"
      else
        set -- "$1" "$2" "$3" "$4%$7\$" "$5" "$6"
      fi
      continue
    fi

    if [ "$6" -le "$3" ]; then
      set -- "$1" "$2" "$3" "$4" "$5 \"\${$6:-}\"" $(($6 + 1))
    else
      set -- "$1" "$2" "$3" "$4%" "$5" $(($6 + 1))
    fi
  done
  unset i18n_work
  eval "$1=\"\${4%\%}@\${5}\""
}

i18n__printf_format_is_parameter_field() {
  set -- "$1" "$2" "${2%%\$*}"
  [ "$2" = "$3" ] && return 1
  case $3 in
    *[!0-9]*) return 1
  esac
  eval "$1=\$3"
}

i18n__printf_format_manipulater() {
  set -- "$1" "$2%" '' '' ''
  while [ "$2" ]; do
    set -- "$1" "${2#*\%}" "$3${2%%\%*}%" "$4"
    case $2 in
      '') continue ;;
      %*) set -- "$1" "${2#%}" "$3%" "$4" && continue ;;
      *)
        case $2 in ([-+\ 0\'\#]*) # flags
          set -- "$1" "$2" "$3" "$4" "${2%%[!-+ 0\'\#]*}"
          if i18n__printf_is_decimal_separator_supported; then
            set -- "$1" "${2#"$5"}" "$3$5" "$4"
          else
            i18n__replace_all i18n_work "$5" "'" ""
            set -- "$1" "${2#"$5"}" "$3$i18n_work" "$4"
            unset i18n_work
          fi
        esac
        case $2 in ([0-9]*) # width
          set -- "$1" "$2" "$3" "$4" "${2%%[!0-9]*}"
          set -- "$1" "${2#"$5"}" "$3$5" "$4"
        esac
        case $2 in (.*) # precision
          set -- "$1" "${2#.}" "$3." "$4"
          set -- "$1" "$2" "$3" "$4" "${2%%[!0-9]*}"
          set -- "$1" "${2#"$5"}" "$3$5" "$4"
        esac
        case $2 in # length + type
          [fFeEgG]* | [hlL][fFeEgG]*) set -- "$1" "$2" "$3" "$4+ " ;;
          *) set -- "$1" "$2" "$3" "$4- " ;;
        esac
        set -- "$1" "$2" "$3" "$4"
    esac
  done
  eval "$1=\"\${3%\%}@\${4}\""
}

i18n__print() {
  i18n_work=$1
  case ${2:-} in
    -n) shift 2 && set -- i18n_printf "$i18n_work" "$@" ;;
    --) shift 2 && set -- i18n_printfln "$i18n_work" "$@" ;;
     *) shift 1 && set -- i18n_printfln "$i18n_work" "$@" ;;
  esac
  unset i18n_work
  "$@"
}

# i18n_print MSGID [-n | --] [ARGUMENT]...
i18n_print() {
  i18n_gettext i18n_work "$1"
  shift
  set -- "$i18n_work" "$@"
  unset i18n_work
  i18n__print "$@"
}

# i18n_nprint MSGID MSGID-PLURAL [-n | --] N [ARGUMENT]...
i18n_nprint() {
  case $3 in
    -n | --) i18n_ngettext i18n_work "$1" "$2" "$4" ;;
    *) i18n_ngettext i18n_work "$1" "$2" "$3" ;;
  esac
  shift 2
  set -- "$i18n_work" "$@"
  unset i18n_work
  i18n__print "$@"
}

# i18n_sprint MSGID [-n | --] [ARGUMENT]...
i18n_sprint() {
  i18n_sgettext i18n_work "$1"
  shift
  set -- "$i18n_work" "$@"
  unset i18n_work
  i18n__print "$@"
}

# i18n_nsprint MSGID MSGID-PLURAL [-n | --] N [ARGUMENT]...
i18n_nsprint() {
  case $3 in
    -n | --) i18n_nsgettext i18n_work "$1" "$2" "$4" ;;
    *) i18n_nsgettext i18n_work "$1" "$2" "$3" ;;
  esac
  shift 2
  set -- "$i18n_work" "$@"
  unset i18n_work
  i18n__print "$@"
}

# i18n_pprint MSGCTXT MSGID [-n | --] [ARGUMENT]...
i18n_pprint() {
  i18n_pgettext i18n_work "$1" "$2"
  shift
  set -- "$i18n_work" "$@"
  unset i18n_work
  i18n__print "$@"
}

# i18n_npprint MSGCTXT MSGID MSGID-PLURAL [-n | --] N [ARGUMENT]...
i18n_npprint() {
  case $3 in
    -n | --) i18n_npgettext i18n_work "$1" "$2" "$3" "$5" ;;
    *) i18n_npgettext i18n_work "$1" "$2" "$3" "$4" ;;
  esac
  shift 3
  set -- "$i18n_work" "$@"
  unset i18n_work
  i18n__print "$@"
}

# i18n_echo ARGUMENT
i18n_echo() { i18n__putln "$1"; }

N_() { i18n_gettext_noop "$@"; }
S_() { i18n_gettext_s2v "$@"; }
V_() { i18n_gettext_a2v "$@"; }
A_() { i18n_gettext_a2a "$@"; }
AA_() { i18n_gettext_a2aa "$@"; }
alias i18n_gettext_a2p='set -- "$@"'
alias @_='set -- "$@"'
alias i18n_set_array='eval set --'

_() { i18n_print "$@"; }
n_() { i18n_nprint "$@"; }
s_() { i18n_sprint "$@"; }
ns_() { i18n_nsprint "$@"; }
p_() { i18n_pprint "$@"; }
np_() { i18n_npprint "$@"; }
