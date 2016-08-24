#!/bin/bash

echo "$(date), f\w black list check initiated."

# Path to nginx logs
LOGS='/var/log/nginx/*.access'

# Path to store per IP files
DOOM_DIR='/tmp/to_be_banned'
[ -d $DOOM_DIR ] || mkdir -p $DOOM_DIR

# Which hits number is considered as a hostile behavior?
MAX_HITS=1000

# Consumed traffic (in bytes) that considered as overkill
MAX_TRAFFIC=$((512 * 1024 * 1024))

# Log format is...
# 31.6.52.216 - - [17/Aug/2016:16:05:55 +0300] ...

# Turn off locale first to get date string as "17/Aug/2016"
today=$(LANG=C date '+%d/%b/%Y')

# Parse today strings only
# According to goaccess man there's 365 strings
host_list=$(cat $LOGS | grep "$today" | goaccess \
    --time-format='%H:%M:%S' \
    --date-format='%d/%b/%Y' \
    --log-format='%h %^[%d:%t %^] "%r" %s %b "%R" "%u"' \
    --no-csv-summary \
    --no-progress \
    --ignore-panel=VISITORS \
    --ignore-panel=REQUESTS \
    --ignore-panel=REQUESTS_STATIC \
    --ignore-panel=NOT_FOUND \
    --ignore-panel=OS \
    --ignore-panel=BROWSERS \
    --ignore-panel=VISIT_TIMES \
    --ignore-panel=REFERRERS \
    --ignore-panel=REFERRING_SITES \
    --ignore-panel=STATUS_CODES \
    --http-protocol=no \
    --http-method=no \
    --output=csv)

# Ban by hits number
for host_line in $host_list; do
    # host_line look like
    # "1",,"hosts","3582","0.00%","1","0.00%","605340","0.00%",,,"220.191.37.84"

    # Extract "hits" field and make sure it's a number
    hits=$(echo $host_line | cut -d '"' -f 6 | grep -E '^[0-9]*$')
    [ -z "$hits" ] && continue

    # Extract IP and make sure it's a valid IPv4 address
    ip=$(echo $host_line | cut -d '"' -f 18 | grep -E '^[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*$')
    [ -z "$ip" ] && continue

    # Too few hits?
    [ $hits -lt $MAX_HITS ] && break

    # Now it's time to deal with annoying guys
    echo "Processing $ip with $hits hits..."
    [ -f $DOOM_DIR/$ip ] || echo $ip > $DOOM_DIR/$ip
done

# Ban by bandwidth consumed
for host_line in $host_list; do
    # Extract "traffic" field and make sure it's a number
    traffic=$(echo $host_line | cut -d '"' -f 14 | grep -E '^[0-9]*$')
    [ -z "$traffic" ] && continue

    # Extract IP and make sure it's a valid IPv4 address
    ip=$(echo $host_line | cut -d '"' -f 18 | grep -E '^[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*$')
    [ -z "$ip" ] && continue

    [ $traffic -lt $MAX_TRAFFIC ] && continue

    # Now it's time to deal with annoying guys
    echo "Processing $ip with $traffic bytes..."
    [ -f $DOOM_DIR/$ip ] || echo $ip > $DOOM_DIR/$ip
done

# Who's atone their sins? One full day in hell is enough, time to unban
find $DOOM_DIR -type f -name '*.*.*.*' -mmin +1440 -delete

mv /etc/ferm/autoblock.list /etc/ferm/autoblock.list.prev

# Is there somebody left in purgatory? The next command will end up with
# error message if $DOOM_DIR is empty, that's normal
cat $DOOM_DIR/*.*.*.* | sort > /etc/ferm/autoblock.list

# Reload f\w rules and poke ryzhovau if ban list has been changed
fw_changes="$(diff -u /etc/ferm/autoblock.list.prev /etc/ferm/autoblock.list | grep -E '^\+[0-9]|^\-[0-9]' | sort)"
[ -z "$fw_changes" ] && exit
systemctl reload ferm
msg='Ban list has been changed:\n'
for i in $fw_changes; do
    case $i in
        +*)
            msg+="• ${i#+} added\n"
        ;;
        -*)
            msg+="• ${i#-} removed\n"
        ;;
    esac
    /home/ryzhovau/scripts/tg_say.sh "$(echo -e $msg)"
done
