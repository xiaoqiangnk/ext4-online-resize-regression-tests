#!/bin/sh

FDISK=fdisk
MOUNT=mount
UMOUNT=umount
MKFS=mkfs
RESIZEFS=resize2fs
FSCK=fsck
feature_list="uninit_bg flex_bg bigalloc meta_bg"
extended_list="lazy_itable_init"

usage()
{
	echo "Usage: resize-tests.sh device mountdir fstype from to"
	exit 1
}

makefs()
{
	opts="-O "
	bit=1
	for feature in $feature_list ; do
		if (($1 & bit)) ; then
			if [ $feature = "meta_bg" ] ; then
				opts="$opts^resize_inode,"
			fi
			opts="$opts$feature,"
		else
			opts="$opts^$feature,"
		fi
		((bit <<= 1))
	done
	opts="$opts -E "
	for feature in $extended_list ; do
		if (($1 & bit)) ;then
			opts="$opts$feature=1,"
		else
			opts="$opts$feature=0,"
		fi
		((bit <<= 1))
	done
 
	echo $MKFS -t $FSTYP $opts $DEVICE $2
	$MKFS -t $FSTYP $opts $DEVICE $2 &>/dev/null || exit 1
}


resizefs()
{
	echo "resizing $DEVICE from $FROM to $TO..."
	if $RESIZEFS $DEVICE $TO >/dev/null ; then
		$UMOUNT $DEVICE
		$FSCK -yf $DEVICE || (echo -e "fsck failed!\n"; exit 1)

		$MOUNT $DEVICE $MNTDIR
		size_human=`df -h /dev/sdc1 | awk '$1~"/dev/sdc1" {sub("\.0", "", $2); print $2}'`
		size=`df /dev/sdc1 | awk '$1~"/dev/sdc1" {print $2}'`
		echo $size $size_human
		if [ $size = $TO ] || [ $size_human = $TO ] ; then
			echo -e "succeeded!\n"
		else
			echo -e "failed!\n"
		fi
	else
		echo -e "failed!\n"
	fi
}

resize_test()
{
	$UMOUNT $DEVICE &>/dev/null
	makefs $1 $FROM
	# test for ext4
	if $MOUNT -t ext4 $DEVICE $MNTDIR &>/dev/null; then
		resizefs
	else
		echo -e "can not mount $DEVICE on $MNTDIR as ext4\n"
	fi
}

resize_tests()
{
	bit=1;
	for feature in $feature_list ; do
		((bit <<= 1))
	done
	for feature in $extended_list ; do
		((bit <<= 1))
	done

	for ((i = 0; i < bit; i++)) ; do
		resize_test i
	done
}


if [ $# -lt 5 ] ; then
	usage
fi

DEVICE=$1
MNTDIR=$2
FSTYP=$3
FROM=$4
TO=$5

case "$FSTYP" in
    ext*)
	 resize_tests
	 ;;
    *)   echo "the filesystem $FSTYP is not supported"
	 ;;
esac
