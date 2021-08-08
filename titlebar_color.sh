#!/bin/bash

## Debugging
# set -x

DEFAULT_COLOR_SCHEME=/usr/share/color-schemes/BreezeDark.colors
LIGHT_COLOR_SCHEME=/usr/share/color-schemes/BreezeLight.colors
KWINRULES=~/.config/kwinrulesrc

echo "Click on app you want to configure"
##     ----- | Find app WM class         | get after '='   | remove "    | remove ,      | change to lowercase     | remove duplicated names 
name=$(xprop | grep "WM_CLASS(STRING) =" | cut -f3- -d " " | sed 's/"//g' | sed 's/,//g' | sed -e 's/\(.*\)/\L\1/' | xargs -n1 | uniq | xargs)
APP_NAME=$(echo $name | sed 's/ //g')
DESCRIPTION="Titlebar color for $APP_NAME"
NEW_COLOR_SCHEME=~/.local/share/color-schemes/$APP_NAME.colors

echo "Select color on the screen"
## Get color and convert hex (#RRGGBB) to dec (RR,GG,BB)
color=$(grabc | awk '{print substr($0, 2)}')
hexinput=`echo $color | tr '[:lower:]' '[:upper:]'`  # uppercase-ing
a=`echo $hexinput | cut -c-2`
b=`echo $hexinput | cut -c3-4`
c=`echo $hexinput | cut -c5-6`
r=`echo "ibase=16; $a" | bc`
g=`echo "ibase=16; $b" | bc`
b=`echo "ibase=16; $c" | bc`

kde_color="$r,$g,$b"
echo "Color: $color ($kde_color)"

## Func for calculating floats
calc() {
    echo "$1" | bc -l | awk '{printf "%f", $0}'
}

## Check if selected color is more sutable with light colorscheme text
calc_color() {
    let color=$1/255
    l_comp=$(calc $color/12.92)
    if (( $(echo "$color > 0.03928" | bc) )); then
        l_comp=$(calc \($color+0.055\)^2.4)
    fi
    echo "$l_comp"
}

## Calculate contrast
calc_r=$(calc_color $r)
calc_g=$(calc_color $g)
calc_b=$(calc_color $b)
l=$(calc "$calc_r*0.2126 + $calc_g*0.7152 + $calc_b*0.0722")
contrast=$(calc 1.05/$l)

## If contrast is less than recommended text (4.5:1), then switch to light
if (( $(echo "$contrast < 4.5" | bc) )); then
    COLOR_SCHEME=$LIGHT_COLOR_SCHEME
else
    COLOR_SCHEME=$DEFAULT_COLOR_SCHEME
fi

## Create a new colorscheme for the app
cp $COLOR_SCHEME $NEW_COLOR_SCHEME
sed -i "s/BackgroundAlternate=.*/BackgroundAlternate=$kde_color/g" $NEW_COLOR_SCHEME
sed -i "s/BackgroundNormal=.*/BackgroundNormal=$kde_color/g" $NEW_COLOR_SCHEME
sed -i "/Name*/d" $NEW_COLOR_SCHEME
echo "Name=$APP_NAME" >> $NEW_COLOR_SCHEME

KGROUPNUM=$(kreadconfig5 --file $KWINRULES --group "General" --key count)

## Check wether the rule already exists
for i in $(seq 1 $KGROUPNUM)
do
    description_value=$(kreadconfig5 --file ~/.config/kwinrulesrc --key Description --group $i)
    if [ "$description_value" = "$DESCRIPTION" ]; then
        group=$i
        break
    fi   
done

if [ -z ${group+x} ]; then
    let KGROUPNUM++

    ## Func for writing config to a new group
    wc() {
        kwriteconfig5 --file $KWINRULES --group "${KGROUPNUM}" --key $1 "$2"
    }
    
    ## New rule
    wc Description "$DESCRIPTION"
    wc decocolor "$APP_NAME"
    wc decocolorrule 2
    wc wmclass "$name"
    wc wmclassmatch 1

    ## Increase config count number
    kwriteconfig5 --file $KWINRULES --group "General" --key count ${KGROUPNUM}

    unset wc
fi

## Apply changes
qdbus org.kde.KWin /KWin reconfigure

unset calc
unset calc_color