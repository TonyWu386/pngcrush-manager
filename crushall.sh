#!/bin/sh

# A multithreaded frontend for pngcrush
# Recommended to make a backup of images before using
# Released under the GNU LGPL v3.0
# github.com/TonyWu386/pngcrush-manager

log_file='crush_log.txt';
temp_suf='_temp.png';
busy_wait_interval=0.5;
mt_limit=4;

h_flag=''
v_flag=''

print_usage() {
    printf "Usage: crushall.sh [OPTION]\n\n \
    -t INT  set number of threads (default 4)\n\n \
    -h      human-readable size units\n\n \
    -v      show pngcrush output\n\n"
}

print_size() {
    case "$h_flag" in
        'true') printf "$(numfmt --to=iec-i --suffix=B $1)" ;;
        *)      printf "$1" ;;
    esac
}

perform_crush() {
    case "$v_flag" in
        'true') pngcrush --check "$1" "$1$temp_suf" | tee $log_file;;
        *) pngcrush --check "$1" "$1$temp_suf" &>>$log_file;;
    esac

    new_size=$(stat --printf="%s" "$1$temp_suf")

    if [ "$new_size" -lt "$2" ] && \
    [ $(file -b "$1$temp_suf" | awk '{print $1}') = "PNG" ]
    then
        reduced_size=$(expr $2 - $new_size)
        printf "$1 job finished: replacing to reduce by "
        printf "$(print_size $reduced_size)\n"
        mv -f "$1$temp_suf" $1
    else
        printf "$1 job finished: NOT replacing\n"
        rm "$1$temp_suf"
    fi
}

while getopts 't:hv' flag
do
    case "${flag}" in
        t) case ${OPTARG} in
               ''|0|*[!0-9]*) print_usage
                              exit 1 ;;
               *) mt_limit=${OPTARG} ;;
           esac ;;
        h) h_flag='true' ;;
        v) v_flag='true' ;;
        *) print_usage
           exit 1 ;;
    esac
done

saved_bytes=0
file_list=$(find ./ -maxdepth 1 -name "*.png")
old_sizes=( )

for png in $file_list;
do
    old_size=$(stat --printf="%s" $png)
    old_sizes+=($old_size)

    while [ $(jobs | awk '{print $2}' | grep Running | wc -l) -ge $mt_limit ]; do
        sleep $busy_wait_interval;
    done
    
    printf "dispatching job for $png\n"
    perform_crush $png $old_size &
done

wait;

printf "all jobs complete\n"

old_size_total=$(echo "${old_sizes[@]/%/+}0" | bc)

new_size_total=0
for png in $file_list;
do
    new_size_total=$(expr $new_size_total + $(stat --printf="%s" $png))
done

printf "reduced by $(print_size $(expr $old_size_total - $new_size_total))\n"
