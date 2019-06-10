#!/bin/bash
#================================================================
# HEADER
#================================================================
#%Usage: ${SCRIPT_NAME} ACTION
#% Simple restoration of installed programs
#%
#%
#%Action:
#%    init                          Executes the scripts in the .scripts in hooks.json
#%    install [groups]              Install the user specified groups. If blank the user can interactively select groups to install.
#%    link                          Link files as specified in .links and .links_root. If the target exists and the files aren't the same, the user will be asked to confirm.
#%    link-normal                   Link files as specified in .links If the target exists and the files aren't the same, the user will be asked to confirm.
#%    link-root                     Link files as specified in .links_root. If the target exists and the files aren't the same, the user will be asked to confirm.
#%    list-groups                   Outputs the list of user defined groups
#%    list-installed                Outputs the list of packages installed than are in a user defined group
#%    list-uninstalled              Outputs the list of packages in a user defined group that are not installed
#%    list-known                    Outputs the list of packages that are in a user defined group
#%    list-unknown                  Outputs the list of packages installed than are not in a user defined group
#%    -h, --help                    Print this help
#%    -v, --version                 Print script information
#%
#%Examples:
#%    ${SCRIPT_NAME} monitor             #start monitoring
#%
#================================================================
#- IMPLEMENTATION
#-    version         ${SCRIPT_NAME} (taaparthur.no-ip.org)
#-    author          Arthur Williams
#-    license         MIT
#================================================================
# END_OF_HEADER
#================================================================
#MAN generated with help2man -No system-manager.1 ./system-manager.sh

set -e

export SYSTEM_CONFIG_DIR=${SYSTEM_CONFIG_DIR:-~/SystemConfig}

displayHelp(){
    SCRIPT_HEADSIZE=$(head -200 ${0} |grep -n "^# END_OF_HEADER" | cut -f1 -d:)
    SCRIPT_NAME="$(basename ${0})"
    head -${SCRIPT_HEADSIZE:-99} ${0} | grep -e "^#[%+]" | sed -e "s/^#[%+-]//g" -e "s/\${SCRIPT_NAME}/${SCRIPT_NAME}/g" ;
}
displayVersion(){
    echo "0.4.0"
}

getAllPackages(){
    cat <(jq -r '. | flatten | join("\n")' $SYSTEM_CONFIG_DIR/packages.json) <(pacman -Qqg base-devel base) |sort|uniq
}
getSedStr(){
    echo "s/([^ ]*) (.*)$/[[ \$(realpath \1) == \$(readlink \2\$(basename \1)) || \$(readlink -f \1) == \$(realpath \2) ]] || ( [[ \2 == *\/ ]] \&\& $1 mkdir -p \2 || $1 mkdir -p $(dirname \2); (diff -q \1 \2\/\$(basename \1) || diff -q \1 \2) \&\& $1 ln -sf \1 \2 || $1 ln -si \1 \2) /g"
}
linkRoot(){
    str='\(.key) \(.value|tostring)'
    bash <(jq -r ".links_root|to_entries|map(\"$str\")|.[]"  $SYSTEM_CONFIG_DIR/hooks.json | sed -E "$(getSedStr sudo)")
}
linkNormal(){
    str='\(.key) \(.value|tostring)'
    bash <(jq -r ".links|to_entries|map(\"$str\")|.[]"  $SYSTEM_CONFIG_DIR/hooks.json | sed -E "$(getSedStr)")
}
linkFiles(){
    linkNormal
    linkRoot
}

options=( $(jq -r 'keys | join(" ")' $SYSTEM_CONFIG_DIR/packages.json |sort))
menu() {
    for i in ${!options[@]}; do
        printf "%3d %s) %s\n" $((i+1)) "${options[i]}" 1>&2
    done
}
selectPackages(){
    #taken from https://serverfault.com/questions/144939/multi-select-menu-in-bash-script

    while true; do
        menu
        read -rp "What do you want installed? " nums
        while read num; do
            if [[ $num == '*' ]]; then
                echo "."
                return 0
            fi
            cmd="echo $num"
            if [[ "$num" == *-* ]]; then
                cmd="seq $(echo "$num" | sed 's/-/ /' )"
            fi
            while read n; do
                [[ "$n" != *[![:digit:]]* ]] &&
                (( n > 0 && n <= ${#options[@]} )) ||
                { echo "Invalid option: $n" 1>&2; continue; }
                ((n--));
                choices[n]="+"
            done < <($cmd)
        done < <(echo "$nums" |sed "s/[ ,]\+/\n/g")
        if [[ ! -z "${choices[*]}" ]]; then
            break
        fi
    done

    for i in ${!options[@]}; do
        [[ "${choices[i]}" ]] && { echo ".${options[i]}"; }
    done
    return 0

}

case "$1" in
    init)
        jq -r '.scripts |join("; ")' $SYSTEM_CONFIG_DIR/hooks.json |bash
        ;;
    install)
        shift
        args="$*"
        if [[ -z "$args" ]]; then
            args=$(echo $(selectPackages)|sed "s/ /, /g")
            echo "Selected $args"
        fi
        packages=$(jq -r "$args | flatten | join(\"\n\")" $SYSTEM_CONFIG_DIR/packages.json |sort)
        set -xe
        ${PKG_MANAGER:-sudo pacman} -S $(echo $packages) --needed

        hooks=$(sort <(jq -r '.install_hooks | keys | join("\n")' $SYSTEM_CONFIG_DIR/hooks.json) <(echo $packages) |uniq -d | xargs -i{} '.{} + "; " + ')
        if [[ ! -z "$hooks" ]]; then
            $(jq "$hooks '' " $SYSTEM_CONFIG_DIR/hooks.json)
        fi
        ;;
     link-normal)
         linkNormal
         ;;
     link-root)
         linkRoot
         ;;
     link)
         linkFiles
         ;;
     list-groups)
        jq -r 'keys | join("\n")' $SYSTEM_CONFIG_DIR/packages.json |sort
       ;;
     list-installed)
         comm -12 <(pacman -Qqe|sort) <(getAllPackages)
       ;;
     list-uninstalled)
         comm -13 <(pacman -Qqe|sort) <(getAllPackages)
       ;;
     list-known)
        getAllPackages
       ;;
     list-unknown)
         comm -23 <(pacman -Qqe|sort) <(getAllPackages)
       ;;
     clean)
         [[ "$(pacman -Qtdq)" ]] && sudo pacman -Rns $(pacman -Qtdq)
         extra=$(comm -23 <(pacman -Qqe|sort) <(getAllPackages))
         sudo pacman -Rnsu $extra
         ;;
    help|--help|-h)
        displayHelp
        ;;
    version | --version|-v)
        displayVersion
        ;;
esac
