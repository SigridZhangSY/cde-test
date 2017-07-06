#!/bin/bash

set -x
user_name=$1
password=$2
DURATION=$3
cde="./cde"
consulURL="http://controller.tzion.me"

success_actions=0
failure_actions=0
current_path=`pwd`
log_path=$current_path/`date +%Y-%m-%d-%H-%M-%S`
log_file_name=$log_path/`date +%Y-%m-%d-%H-%M-%S`log.txt
START_TIME=$SECONDS
# DURATION=$((15*60))

getStackList(){
	read data
	stackList=()
	while read data
	do
		line=($data)
		stackList+=(${line[1]})
	done

	echo ${stackList[@]}
}

scaffoldAndCreateApp(){
	local stackName=$1
	local appName=$2
	
	${cde} scaffold $stackName -a $appName
	
	cp cde $current_path/$appName
	cd $current_path/$appName
	if [ $? -eq 0 ]
	then
    	eval $(ssh-agent -s)
		ssh-keygen -b 2048 -t rsa -f demokey -q -N ""
		ssh-add demokey
		${cde} keys:add demokey.pub
	
		git add .
		git commit -m 'init commit'
		git push cde master
		cd $current_path
	fi
}

deleteAppAndPath(){
	local appName=$1

	cp cde $current_path/$appName
	cd $current_path/$appName
	if [ $? -eq 0 ]
	then
		pwd
		${cde} apps:destroy
		cd $current_path
		# rm -rf $current_path/$appName
	fi
}

report(){
	local appName=$1
	local start=$2
	local end=$3
	local status=0

	while read line
	do
		if [[ `echo $line | tr "[:upper:]" "[:lower:]"` == *"error"* ]]
		then
			status=1
			printf '\e[1;31m%-6s\e[m \n' "===========app $appName : Fail==========="
			failure_actions=$((failure_actions+1))
			local logLine="$((success_actions+failure_actions))\t$appName\tFail"
			break
		fi
	done < $log_path/$appName.txt

	if [[ $status == 0 ]]
	then
		printf '\e[1;32m%-6s\e[m \n' "===========app $appName : OK==========="
		success_actions=$((success_actions+1))
		local logLine="$((success_actions+failure_actions))\t$appName\tOK"
	fi
	local duration=$(($end-$start))
	logLine="$logLine\t`date -d @$start`\t\t`date -d @$end`\t\t$duration\n"

	echo -en $logLine >> $log_file_name
}


apt-get update
apt-get -y install curl
curl -L https://github.com/tw-cde/cde-client-binary/releases/download/v0.1.9/cde_linux_amd64 -o cde
chmod +x cde
apt-get -y install git

if [ "$DURATION" = "" ]
then
	echo "input DURATION:"
    read DURATION
fi


if [ "$user_name" = "" ]
then
    echo "input username:"
    read user_name
fi

if [ "$password" = "" ]
then
    echo "input password:"
    read password
fi

mkdir ~/.ssh
touch ~/.ssh/config
echo -en "Host controller.tzion.me\n\tStrictHostKeyChecking no\n" > ~/.ssh/config
git config --global user.email $user_name
git config --global user.name $user_name

${cde} auth:login $consulURL --email $user_name --password $password
mkdir $log_path
echo -en "NO\t\tAppName\t\tstatus\t\tstart\t\tend\t\tduration(s)\n" >> $log_file_name
while :
do
	stackList=($(${cde} stacks:list | getStackList))
	for i in ${stackList[@]}
	do
		app_start_time=`date +%s`
		appName=$i-$app_start_time
		scaffoldAndCreateApp $i $appName > "$log_path/$appName.txt" 2>&1
		app_end_time=`date +%s`
		report $appName $app_start_time $app_end_time
		deleteAppAndPath $appName
		if [[ $(($SECONDS-$START_TIME)) -gt $DURATION ]]
		then
			echo "success: $success_actions" >> $log_file_name
			echo "failure: $failure_actions" >> $log_file_name
			exit 0
		fi
	done
done


