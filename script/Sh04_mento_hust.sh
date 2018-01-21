#!/bin/sh
#copyright by hiboy
source /etc/storage/script/init.sh
mentohust_enable=`nvram get mentohust_enable`
[ -z $mentohust_enable ] && mentohust_enable=0 && nvram set mentohust_enable=0
if [ "$mentohust_enable" != "0" ] ; then
#nvramshow=`nvram showall | grep '=' | grep mentohust | awk '{print gensub(/'"'"'/,"'"'"'\"'"'"'\"'"'"'","g",$0);}'| awk '{print gensub(/=/,"='\''",1,$0)"'\'';";}'` && eval $nvramshow
mentohust_path=`nvram get mentohust_path`
[ -z $mentohust_path ] && mentohust_path="/usr/bin/mentohust" && nvram set mentohust_path=$mentohust_path
mentohust_n=`nvram get mentohust_n`
[ -z $mentohust_n ] && mentohust_n=$(nvram get wan0_ifname_t) && nvram set mentohust_n=$mentohust_n
mentohust_i=`nvram get mentohust_i`
[ -z $mentohust_i ] && mentohust_i="0.0.0.0" && nvram set mentohust_i=$mentohust_i
mentohust_m=`nvram get mentohust_m`
[ -z $mentohust_m ] && mentohust_m=$(nvram get lan_netmask) && nvram set mentohust_m=$mentohust_m
mentohust_g=`nvram get mentohust_g`
[ -z $mentohust_g ] && mentohust_g="0.0.0.0" && nvram set mentohust_g=$mentohust_g
mentohust_s=`nvram get mentohust_s`
[ -z $mentohust_s ] && mentohust_s="0.0.0.0" && nvram set mentohust_s=$mentohust_s
mentohust_o=`nvram get mentohust_o`
[ -z $mentohust_o ] && mentohust_o="0.0.0.0" && nvram set mentohust_o=$mentohust_o
mentohust_t=`nvram get mentohust_t`
[ -z $mentohust_t ] && mentohust_t="8" && nvram set mentohust_t=$mentohust_t
mentohust_e=`nvram get mentohust_e`
[ -z $mentohust_e ] && mentohust_e="30" && nvram set mentohust_e=$mentohust_e
mentohust_r=`nvram get mentohust_r`
[ -z $mentohust_r ] && mentohust_r="15" && nvram set mentohust_r=$mentohust_r
mentohust_l=`nvram get mentohust_l`
[ -z $mentohust_l ] && mentohust_l="8" && nvram set mentohust_l=$mentohust_l
mentohust_a=`nvram get mentohust_a`
[ -z $mentohust_a ] && mentohust_a="0" && nvram set mentohust_a=$mentohust_a
mentohust_d=`nvram get mentohust_d`
[ -z $mentohust_d ] && mentohust_d="0" && nvram set mentohust_d=$mentohust_d
mentohust_b=`nvram get mentohust_b`
[ -z $mentohust_b ] && mentohust_b="0" && nvram set mentohust_b=$mentohust_b
mentohust_v=`nvram get mentohust_v`
[ -z $mentohust_v ] && mentohust_v="0.00" && nvram set mentohust_v=$mentohust_v
mentohust_c=`nvram get mentohust_c`
[ -z $mentohust_c ] && mentohust_c="dhclinet" && nvram set mentohust_c=$mentohust_c
mentohust_f=`nvram get mentohust_f`
mentohust_u=`nvram get mentohust_u`
mentohust_p=`nvram get mentohust_p`
mentohust_mode=`nvram get mentohust_mode`
fi

if [ ! -z "$(echo $scriptfilepath | grep -v "/tmp/script/" | grep mento_hust)" ]  && [ ! -s /tmp/script/_mento_hust ]; then
	mkdir -p /tmp/script
	{ echo '#!/bin/sh' ; echo $scriptfilepath '"$@"' '&' ; } > /tmp/script/_mento_hust
	chmod 777 /tmp/script/_mento_hust
fi

mentohust_restart () {

relock="/var/lock/mentohust_restart.lock"
if [ "$1" = "o" ] ; then
	nvram set mentohust_renum="0"
	[ -f $relock ] && rm -f $relock
	return 0
fi
if [ "$1" = "x" ] ; then
	if [ -f $relock ] ; then
		logger -t "【MentoHUST】" "多次尝试启动失败，等待【"`cat $relock`"分钟】后自动尝试重新启动"
		exit 0
	fi
	mentohust_renum=${mentohust_renum:-"0"}
	mentohust_renum=`expr $mentohust_renum + 1`
	nvram set mentohust_renum="$mentohust_renum"
	if [ "$mentohust_renum" -gt "2" ] ; then
		I=19
		echo $I > $relock
		logger -t "【MentoHUST】" "多次尝试启动失败，等待【"`cat $relock`"分钟】后自动尝试重新启动"
		while [ $I -gt 0 ]; do
			I=$(($I - 1))
			echo $I > $relock
			sleep 60
			[ "$(nvram get mentohust_renum)" = "0" ] && exit 0
			[ $I -lt 0 ] && break
		done
		nvram set mentohust_renum="0"
	fi
	[ -f $relock ] && rm -f $relock
fi
nvram set mentohust_status=0
eval "$scriptfilepath &"
exit 0
}

mentohust_get_status () {

A_restart=`nvram get mentohust_status`
B_restart="$mentohust_enable$mentohust_path$mentohust_u$mentohust_p$mentohust_n$mentohust_i$mentohust_m$mentohust_g$mentohust_s$mentohust_o$mentohust_t$mentohust_e$mentohust_r$mentohust_a$mentohust_d$mentohust_b$mentohust_v$mentohust_f$mentohust_c$mentohust_mode"
B_restart=`echo -n "$B_restart" | md5sum | sed s/[[:space:]]//g | sed s/-//g`
if [ "$A_restart" != "$B_restart" ] ; then
	nvram set mentohust_status=$B_restart
	needed_restart=1
else
	needed_restart=0
fi
}

mentohust_check () {

mentohust_get_status
if [ "$mentohust_enable" != "1" ] && [ "$needed_restart" = "1" ] ; then
	[ ! -z "`pidof mentohust`" ] && logger -t "【MentoHUST】" "停止 mentohust" && mentohust_close
	{ eval $(ps -w | grep "$scriptname" | grep -v grep | awk '{print "kill "$1";";}'); exit 0; }
fi
if [ "$mentohust_enable" = "1" ] ; then
	if [ "$needed_restart" = "1" ] ; then
		#配置有变，重新生成
		rm -f /etc/storage/mentohust.conf
		mentohust_close
		mentohust_start
	else
		[ -z "`pidof mentohust`" ] && mentohust_restart
	fi
fi
}

mentohust_keep () {
logger -t "【mentohust】" "守护进程启动"
if [ -s /tmp/script/_opt_script_check ]; then
sed -Ei '/【mentohust】|^$/d' /tmp/script/_opt_script_check
cat >> "/tmp/script/_opt_script_check" <<-OSC
[ -z "\`pidof mentohust\`" ] || [ ! -s "$mentohust_path" ] && nvram set mentohust_status=00 && logger -t "【mentohust】" "重新启动" && eval "$scriptfilepath &" && sed -Ei '/【mentohust】|^$/d' /tmp/script/_opt_script_check # 【mentohust】
OSC
return
fi
while true; do
	if [ -z "`pidof mentohust`" ] || [ ! -s "$mentohust_path" ] ; then
		logger -t "【mentohust】" "重新启动"
		mentohust_restart
	fi
sleep 104
done
}

mentohust_close () {
sed -Ei '/【mentohust】|^$/d' /tmp/script/_opt_script_check
killall mentohust
killall -9 mentohust
eval $(ps -w | grep "_mento_hust keep" | grep -v grep | awk '{print "kill "$1";";}')
eval $(ps -w | grep "_mento_hust.sh keep" | grep -v grep | awk '{print "kill "$1";";}')
eval $(ps -w | grep "$scriptname keep" | grep -v grep | awk '{print "kill "$1";";}')
}

mentohust_start () {
SVC_PATH="$mentohust_path"
if [ ! -s "$SVC_PATH" ] ; then
	SVC_PATH="/usr/bin/mentohust"
fi
if [ ! -s "$SVC_PATH" ] ; then
	SVC_PATH="/opt/bin/mentohust"
fi
chmod 777 "$SVC_PATH"
[[ "$(mentohust -h | wc -l)" -lt 2 ]] && rm -rf /opt/bin/mentohust
if [ ! -s "$SVC_PATH" ] ; then
	logger -t "【MentoHUST】" "找不到 $SVC_PATH ，安装 opt 程序"
	/tmp/script/_mountopt start
	initopt
fi
if [ ! -s "$SVC_PATH" ] ; then
	logger -t "【MentoHUST】" "找不到 $SVC_PATH 下载程序"
	wgetcurl.sh /opt/bin/mentohust "$hiboyfile/mentohust" "$hiboyfile2/mentohust"
	chmod 755 "/opt/bin/mentohust"
else
	logger -t "【MentoHUST】" "找到 $SVC_PATH"
fi
if [ ! -s "$SVC_PATH" ] ; then
	logger -t "【MentoHUST】" "找不到 $SVC_PATH ，需要手动安装 $SVC_PATH"
	logger -t "【MentoHUST】" "启动失败, 10 秒后自动尝试重新启动" && sleep 10 && mentohust_restart x
fi
if [ -s "$SVC_PATH" ] ; then
	nvram set mentohust_path="$SVC_PATH"
fi
mentohust_path="$SVC_PATH"

logger -t "【MentoHUST】" "运行 $mentohust_path"

#保存配置到文件
if [ ! -f "/etc/storage/mentohust.conf" ] ; then
	$mentohust_path -u$mentohust_u -p$mentohust_p -n$mentohust_n -i$mentohust_i -m$mentohust_m -g$mentohust_g -s$mentohust_s -o$mentohust_o -t$mentohust_t -e$mentohust_e -r$mentohust_r -l$mentohust_l -a$mentohust_a -d$mentohust_d -b$mentohust_b -v$mentohust_v -f$mentohust_f  -c$mentohust_c -w 
	sleep 2
	pids=$(pidof process) && killall -9 $pids
fi
mentohust_mode=`nvram get mentohust_mode`
if [ "$mentohust_mode" = "0" ] ; then
logger -t "【MentoHUST】" "标准模式"
	$mentohust_path &
elif [ "$mentohust_mode" = "1" ] ; then
logger -t "【MentoHUST】" "锐捷模式"
   $mentohust_path  -y &
elif [ "$mentohust_mode" = "2" ] ; then
logger -t "【MentoHUST】" "赛尔模式"
   $mentohust_path -s8.8.8.8 &
fi
sleep 2
restart_firewall
[ ! -z "`pidof mentohust`" ] && logger -t "【MentoHUST】" "启动成功" && mentohust_restart o
[ -z "`pidof mentohust`" ] && logger -t "【MentoHUST】" "启动失败, 注意检查端口是否有冲突,程序是否下载完整,10 秒后自动尝试重新启动" && sleep 10 && mentohust_restart x
#mentohust_get_status
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
	mentohust_close
	mentohust_check
	;;
check)
	mentohust_check
	;;
stop)
	mentohust_close
	;;
keep)
	#mentohust_check
	mentohust_keep
	;;
*)
	mentohust_check
	;;
esac

