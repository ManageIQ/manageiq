require_relative './test_helper'

require 'platform'

# This test runs all disk & file system tests on all VMs.
# Each test case is responsible for pulling it's own VMs
# from the respository (vms.yml).

# Uncomment $miq_test_deep to run full test (touches all mft entries & inodes).
# Uncomment $miq_test_write to run write tests.
#$miq_test_deep = true
#$miq_test_write = true

# Use to switch tests on/off.
miq_test_largefile	= true
miq_test_disk				= true
miq_test_registry		= true
miq_test_fat32			= true
miq_test_ntfs				= true
miq_test_ext3				= true

if $log.nil?
	puts "Initializing log"
	require 'util/miq-logger'
	include Log4r
	$log = MIQLogger.get_log(nil, 'mdfs.log')
	$log.outputters.delete(Outputter.stdout)
end

# MiqLargeFile tests.
if miq_test_largefile
	puts "Testing largefile"
	require_relative 'DiskTestCommon/tc_MiqLargeFile'
end

# MiqDisk tests.
if miq_test_disk
	puts "Testing disk"
	require_relative 'DiskTestCommon/tc_MiqDisk'
	require_relative 'DiskTestCommon/tc_MiqDisk_read_length'
	require_relative 'DiskTestCommon/tc_MiqDisk_write' if $miq_test_write
	require_relative 'DiskTestCommon/tc_seek'
end

# Windows specific.
if miq_test_registry
	puts "Testing registry"
	require_relative 'DiskTestCommon/tc_vfyreg'
end

# Fat32 tests.
if miq_test_fat32
	puts "Testing fat32"
	require_relative 'DiskTestCommon/fat32/tc_fat32_boot'
	require_relative 'DiskTestCommon/fat32/tc_fat32_rootdir'
	require_relative 'DiskTestCommon/fat32/tc_fat32_file'
	require_relative 'DiskTestCommon/fat32/tc_fat32_write' if $miq_test_write
end

# NTFS tests.
if miq_test_ntfs
	puts "Testing ntfs"
	require_relative 'DiskTestCommon/ntfs/tc_ntfs_boot'
	require_relative 'DiskTestCommon/ntfs/tc_ntfs_mft'
	require_relative 'DiskTestCommon/ntfs/tc_ntfs_index'
	#require_relative 'DiskTestCommon/ntfs/tc_ntfs_file'
	#require_relative 'DiskTestCommon/ntfs/tc_ntfs_write' if $miq_test_write #doesn't exist yet.
end

# Ext3 tests.
if miq_test_ext3
	puts "Testing ext3"
	#require 'tc_ext3_cache'
	require_relative 'DiskTestCommon/ext3/tc_ext3_superblock'
	require_relative 'DiskTestCommon/ext3/tc_ext3_directory'
	require_relative 'DiskTestCommon/ext3/tc_ext3_file'
	#require_relative 'DiskTestCommon/ext3/tc_ext3_write' if $miq_test_write #doesn't exist yet.
end
