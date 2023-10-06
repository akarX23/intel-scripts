#!/bin/bash
#This script was created by NPG Performance Measurement and Analysis Team.
#written by Jon Strang <jon.strang@intel.com>
main()
{
	parse_args $@
	calculate_processes
	create_configs
}
calculate_processes()
{
	PROCESES_PER_DEVICE=0
	AVAILABLE_PROCESES_PER_DEVICE=$(($PROCESSES/$DEVICES+$PROCESSES%$DEVICES))

	if [ $PROCESSES -lt $DEVICES ];
	then
		PROCESSES_PER_DEVICE=1
	elif [ $PROCESSES -ge $DEVICES ];
	then
		for i in `seq 0 1 $(($AVAILABLE_PROCESES_PER_DEVICE-1))`
		do
			PROCESSES_PER_DEVICE=$((PROCESSES_PER_DEVICE+1))
		done
	fi
}
create_configs()
{
	CORE_LEFT_OFF_AT=0
	CORE_STRING=""
	for i in `seq 0 1 $((DEVICES-1))`;
	do
		echo "[GENERAL]	"								>>device_"$i".conf
		echo "ServicesEnabled = cy,dc"							>>device_"$i".conf
		echo "ConfigVersion = 2"							>>device_"$i".conf
		echo "CyNumConcurrentSymRequests = 512"						>>device_"$i".conf
		echo "CyNumConcurrentAsymRequests = 64"						>>device_"$i".conf
		echo "statsGeneral = 1"								>>device_"$i".conf
		echo "statsDh = 1"								>>device_"$i".conf
		echo "statsDrbg = 1"								>>device_"$i".conf
		echo "statsDsa = 1"								>>device_"$i".conf
		echo "statsEcc = 1"								>>device_"$i".conf
		echo "statsKeyGen = 1"								>>device_"$i".conf
		echo "statsDc = 1"								>>device_"$i".conf
		echo "statsLn = 1"								>>device_"$i".conf
		echo "statsPrime = 1"								>>device_"$i".conf
		echo "statsRsa = 1"								>>device_"$i".conf
		echo "statsSym = 1"								>>device_"$i".conf
		echo "StorageEnabled = 0"							>>device_"$i".conf
		echo "PkeDisabled = 0"								>>device_"$i".conf
		echo "InterBuffLogVal = 14"							>>device_"$i".conf
		echo ""										>>device_"$i".conf
		echo "[KERNEL]"									>>device_"$i".conf
		echo "NumberCyInstances = 0"							>>device_"$i".conf
		echo "NumberDcInstances = 0"							>>device_"$i".conf
		echo "Cy0Name = "IPSec0""							>>device_"$i".conf
		echo "Cy0IsPolled = 0"								>>device_"$i".conf
		echo "Cy0CoreAffinity = 0"							>>device_"$i".conf
		echo "Dc0Name = "IPComp0""							>>device_"$i".conf
		echo "Dc0IsPolled = 0"								>>device_"$i".conf
		echo "Dc0CoreAffinity = 0"							>>device_"$i".conf
		echo ""										>>device_"$i".conf
		echo "[SHIM]"									>>device_"$i".conf
		echo "NumberCyInstances = 1"							>>device_"$i".conf
		echo "NumberDcInstances = 1"							>>device_"$i".conf
		echo "NumProcesses = $PROCESSES_PER_DEVICE"					>>device_"$i".conf
		echo "LimitDevAccess = 1"							>>device_"$i".conf
		echo "Cy0Name = "UserCY0""							>>device_"$i".conf
		echo "Cy0IsPolled = 1"								>>device_"$i".conf

		START_FROM=$(($OFFSET+$CORE_LEFT_OFF_AT))
		if [ $HT = 'n' ];
		then
			if [ $(($PROCESSES%$DEVICES)) -eq 0 ];
			then
				for j in `seq 0 1 $(($PROCESSES/$DEVICES-1))`;
				do
					CORE_STRING+="$(($j+$START_FROM)),"
					CORE_LEFT_OFF_AT=$(($CORE_LEFT_OFF_AT+1))
				done
			else
				for j in `seq 0 1 $(($PROCESSES/$DEVICES))`;
				do
					CORE_STRING+="$(($j+$START_FROM)),"
					CORE_LEFT_OFF_AT=$(($CORE_LEFT_OFF_AT+1))
				done
			fi
		else
			HT_CORES=""
			HT_OFFSET=$(($NUM_CORES/$NUMA+$OFFSET))
			if [ $(($PROCESSES%$DEVICES)) -eq 0 ];
			then
				for j in `seq 0 1 $((($PROCESSES/2)/$DEVICES))`;
				do
					HT_CORES+="$(($j+$START_FROM+$HT_OFFSET-1)),"
					CORE_STRING+="$(($j+$START_FROM)),"
					CORE_LEFT_OFF_AT=$(($CORE_LEFT_OFF_AT+1))
				done
			else
				for j in `seq 0 1 $((($PROCESSES/2)/$DEVICES))`;
				do
					HT_CORES+="$(($j+$START_FROM+$HT_OFFSET-1)),"
					CORE_STRING+="$(($j+$START_FROM)),"
					CORE_LEFT_OFF_AT=$(($CORE_LEFT_OFF_AT+1))
				done
			fi
			CORE_STRING+="$CORES_STRING$HT_CORES"
		fi
		echo "Cy0CoreAffinity = $CORE_STRING" |sed 's/,$//g'						>>device_"$i".conf
		CORE_STRING=""
		HT_CORES=""
	done
}
usage()
{
	echo "./create_qat_files.sh -d <number of qat devices> -p <number of processes e.g. nginx or haproxy> -o <core offset> -ht <hyper-threads y|n>"
	echo ""
	echo "Ex.) 18 nginx workers with no HT used and 3 devices and you want to pin nginx beginning with core 1"
	echo "./create_qat_files.sh -d 3 -p 18 -o 1 -ht n"
	echo "Ex.) 18 nginx workers !with! HT used and 3 devices and you want to pin nginx beginning with core 1"
	echo "./create_qat_files.sh -d 3 -p 36 -o 1 -ht y"
}
parse_args()
{
	CORRECTNESS=0
	while true;
	do
		case "$1" in
			-h)
				usage
				exit 0
				shift;shift;;
			-o)
				if [ $2 ];
				then
					OFFSET=$2
					CORRECTNESS=$((CORRECTNESS+1))
				fi
				shift;shift;;
			-d)
				if [ $2 ];
				then
					DEVICES=$2
					CORRECTNESS=$((CORRECTNESS+1))
				fi
				shift;shift;;
			-p)
				if [ $2 ];
				then
					PROCESSES=$2
					CORRECTNESS=$((CORRECTNESS+1))
				fi
				shift;shift;;
			-ht)
				if [ ! $2 = 'y' ] && [ ! $2 = 'n' ];
				then
					echo "Sorry, your -ht needs to be either y|n"
					exit -1
				fi
				if [ $2 ];
				then
					HT=$2
					CORRECTNESS=$((CORRECTNESS+1))
				fi
				NUMA=`lscpu |grep -i numa |grep -v ",\|-" |awk '{print $NF}'`
				NUM_CORES=`nproc`
				shift;shift;;
			*)
				break;
		esac
	done
	if [ $CORRECTNESS -lt 4 ];
	then
		usage
		exit -1
	fi
}
main $@
