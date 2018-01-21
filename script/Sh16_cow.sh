#!/bin/sh
#copyright by hiboy
source /etc/storage/script/init.sh
cow_enable=`nvram get cow_enable`
[ -z $cow_enable ] && cow_enable=0 && nvram set cow_enable=0
cow_path=`nvram get cow_path`
[ -z $cow_path ] && cow_path="/opt/bin/cow" && nvram set cow_path=$cow_path
if [ "$cow_enable" != "0" ] ; then
#nvramshow=`nvram showall | grep '=' | grep ss | awk '{print gensub(/'"'"'/,"'"'"'\"'"'"'\"'"'"'","g",$0);}'| awk '{print gensub(/=/,"='\''",1,$0)"'\'';";}'` && eval $nvramshow
#nvramshow=`nvram showall | grep '=' | grep cow | awk '{print gensub(/'"'"'/,"'"'"'\"'"'"'\"'"'"'","g",$0);}'| awk '{print gensub(/=/,"='\''",1,$0)"'\'';";}'` && eval $nvramshow

kcptun2_enable=`nvram get kcptun2_enable`
kcptun2_enable2=`nvram get kcptun2_enable2`
ss_mode_x=`nvram get ss_mode_x`
ss_s1_local_port=`nvram get ss_s1_local_port`
ss_s2_local_port=`nvram get ss_s2_local_port`
ss_rdd_server=`nvram get ss_server2`

[ -z $ss_mode_x ] && ss_mode_x=0 && nvram set ss_mode_x=$ss_mode_x
[ -z $kcptun2_enable ] && kcptun2_enable=0 && nvram set kcptun2_enable=$kcptun2_enable
[ -z $kcptun2_enable2 ] && kcptun2_enable2=0 && nvram set kcptun2_enable2=$kcptun2_enable2
[ "$kcptun2_enable" = "2" ] && ss_rdd_server=""
[ -z $ss_s1_local_port ] && ss_s1_local_port=1081 && nvram set ss_s1_local_port=$ss_s1_local_port
[ -z $ss_s2_local_port ] && ss_s2_local_port=1082 && nvram set ss_s2_local_port=$ss_s2_local_port
fi


if [ ! -z "$(echo $scriptfilepath | grep -v "/tmp/script/" | grep cow)" ]  && [ ! -s /tmp/script/_cow ]; then
	mkdir -p /tmp/script
	{ echo '#!/bin/sh' ; echo $scriptfilepath '"$@"' '&' ; } > /tmp/script/_cow
	chmod 777 /tmp/script/_cow
fi

cow_restart () {

relock="/var/lock/cow_restart.lock"
if [ "$1" = "o" ] ; then
	nvram set cow_renum="0"
	[ -f $relock ] && rm -f $relock
	return 0
fi
if [ "$1" = "x" ] ; then
	if [ -f $relock ] ; then
		logger -t "【cow】" "多次尝试启动失败，等待【"`cat $relock`"分钟】后自动尝试重新启动"
		exit 0
	fi
	cow_renum=${cow_renum:-"0"}
	cow_renum=`expr $cow_renum + 1`
	nvram set cow_renum="$cow_renum"
	if [ "$cow_renum" -gt "2" ] ; then
		I=19
		echo $I > $relock
		logger -t "【cow】" "多次尝试启动失败，等待【"`cat $relock`"分钟】后自动尝试重新启动"
		while [ $I -gt 0 ]; do
			I=$(($I - 1))
			echo $I > $relock
			sleep 60
			[ "$(nvram get cow_renum)" = "0" ] && exit 0
			[ $I -lt 0 ] && break
		done
		nvram set cow_renum="0"
	fi
	[ -f $relock ] && rm -f $relock
fi
nvram set cow_status=0
eval "$scriptfilepath &"
exit 0
}

cow_get_status () {

lan_ipaddr=`nvram get lan_ipaddr`
A_restart=`nvram get cow_status`
B_restart="$cow_enable$cow_path$lan_ipaddr$ss_s1_local_port$ss_s2_local_port$ss_mode_x$ss_rdd_server$(cat /etc/storage/cow_script.sh /etc/storage/cow_config_script.sh | grep -v '^#' | grep -v "^$")"
B_restart=`echo -n "$B_restart" | md5sum | sed s/[[:space:]]//g | sed s/-//g`
if [ "$A_restart" != "$B_restart" ] ; then
	nvram set cow_status=$B_restart
	needed_restart=1
else
	needed_restart=0
fi
}

cow_check () {

cow_get_status
if [ "$cow_enable" != "1" ] && [ "$needed_restart" = "1" ] ; then
	[ ! -z "$(ps -w | grep "$cow_path" | grep -v grep )" ] && logger -t "【cow】" "停止 cow" && cow_close
	{ eval $(ps -w | grep "$scriptname" | grep -v grep | awk '{print "kill "$1";";}'); exit 0; }
fi
if [ "$cow_enable" = "1" ] ; then
	if [ "$needed_restart" = "1" ] ; then
		cow_close
		cow_start
	else
		[ -z "$(ps -w | grep "$cow_path" | grep -v grep )" ] && cow_restart
	fi
fi
}

cow_keep () {
logger -t "【cow】" "守护进程启动"
if [ -s /tmp/script/_opt_script_check ]; then
sed -Ei '/【cow】|^$/d' /tmp/script/_opt_script_check
cat >> "/tmp/script/_opt_script_check" <<-OSC
	NUM=\`grep "$cow_path" /tmp/ps | grep -v grep |wc -l\` # 【cow】
	if [ "\$NUM" -lt "1" ] || [ ! -s "$cow_path" ] ; then # 【cow】
		logger -t "【cow】" "重新启动\$NUM" # 【cow】
		nvram set cow_status=00 && eval "$scriptfilepath &" && sed -Ei '/【cow】|^$/d' /tmp/script/_opt_script_check # 【cow】
	fi # 【cow】
OSC
return
fi

while true; do
	NUM=`ps -w | grep "$cow_path" | grep -v grep |wc -l`
	if [ "$NUM" -lt "1" ] || [ ! -s "$cow_path" ] ; then
		logger -t "【cow】" "重新启动$NUM"
		cow_restart
	fi
sleep 216
done
}

cow_close () {
sed -Ei '/【cow】|^$/d' /tmp/script/_opt_script_check
[ ! -z "$cow_path" ] && eval $(ps -w | grep "$cow_path" | grep -v grep | awk '{print "kill "$1";";}')
killall cow cow_script.sh
killall -9 cow cow_script.sh
eval $(ps -w | grep "_cow keep" | grep -v grep | awk '{print "kill "$1";";}')
eval $(ps -w | grep "_cow.sh keep" | grep -v grep | awk '{print "kill "$1";";}')
eval $(ps -w | grep "$scriptname keep" | grep -v grep | awk '{print "kill "$1";";}')
}

cow_start () {
SVC_PATH="$cow_path"
if [ ! -s "$SVC_PATH" ] ; then
	SVC_PATH="/opt/bin/cow"
fi
chmod 777 "$SVC_PATH"
[[ "$(cow -h 2>&1 | wc -l)" -lt 2 ]] && rm -rf /opt/bin/cow
if [ ! -s "$SVC_PATH" ] ; then
	logger -t "【cow】" "找不到 $SVC_PATH，安装 opt 程序"
	/tmp/script/_mountopt start
fi
if [ ! -s "$SVC_PATH" ] ; then
	logger -t "【cow】" "找不到 $SVC_PATH 下载程序"
	wgetcurl.sh /opt/bin/cow "$hiboyfile/cow" "$hiboyfile2/cow"
	chmod 755 "/opt/bin/cow"
else
	logger -t "【cow】" "找到 $SVC_PATH"
fi
if [ ! -s "$SVC_PATH" ] ; then
	logger -t "【cow】" "找不到 $SVC_PATH ，需要手动安装 $SVC_PATH"
	logger -t "【cow】" "启动失败, 10 秒后自动尝试重新启动" && sleep 10 && cow_restart x
fi
if [ -s "$SVC_PATH" ] ; then
	nvram set cow_path="$SVC_PATH"
fi
cow_path="$SVC_PATH"

logger -t "【cow】" "运行 cow_script"
/etc/storage/cow_script.sh
$cow_path -rc /etc/storage/cow_config_script.sh &
restart_dhcpd
sleep 2
[ ! -z "$(ps -w | grep "$cow_path" | grep -v grep )" ] && logger -t "【cow】" "启动成功" && cow_restart o
[ -z "$(ps -w | grep "$cow_path" | grep -v grep )" ] && logger -t "【cow】" "启动失败, 注意检查端口是否有冲突,程序是否下载完整,10 秒后自动尝试重新启动" && sleep 10 && cow_restart x
initopt
cow_get_status
eval "$scriptfilepath keep &"
}

initopt () {
optPath=`grep ' /opt ' /proc/mounts | grep tmpfs`
[ ! -z "$optPath" ] && return
if [ ! -z "$(echo $scriptfilepath | grep -v "/opt/etc/init")" ] && [ -s "/opt/etc/init.d/rc.func" ] ; then
	{ echo '#!/bin/sh' ; echo $scriptfilepath '"$@"' '&' ; } > /opt/etc/init.d/$scriptname && chmod 777  /opt/etc/init.d/$scriptname
fi

}

case $ACTION in
start)
	cow_close
	cow_check
	;;
check)
	cow_check
	;;
stop)
	cow_close
	;;
keep)
	#cow_check
	cow_keep
	;;
*)
	cow_check
	;;
esac

