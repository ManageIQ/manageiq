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
	$:.push("#{File.dirname(__FILE__)}/../util")
	require 'miq-logger'
	include Log4r
	$log = MIQLogger.get_log(nil, 'mdfs.log')
	$log.outputters.delete(Outputter.stdout)
end

# MiqLargeFile tests.
if miq_test_largefile
	puts "Testing largefile"
	$:.push("#{File.dirname(__FILE__)}/DiskTestCommon")
	require 'tc_MiqLargeFile'
end

# MiqDisk tests.
if miq_test_disk
	puts "Testing disk"
	$:.push("#{File.dirname(__FILE__)}/DiskTestCommon")
	require 'tc_MiqDisk'
	require 'tc_MiqDisk_read_length'
	require 'tc_MiqDisk_write' if $miq_test_write
	require 'tc_seek'
end

# Windows specific.
if miq_test_registry
	puts "Testing registry"
	$:.push("#{File.dirname(__FILE__)}/DiskTestCommon")
	require 'tc_vfyreg'
end

# Fat32 tests.
if miq_test_fat32
	puts "Testing fat32"
	$:.push("#{File.dirname(__FILE__)}/DiskTestCommon/fat32")
	require 'tc_fat32_boot'
	require 'tc_fat32_rootdir'
	require 'tc_fat32_file'
	require 'tc_fat32_write' if $miq_test_write
end

# NTFS tests.
if miq_test_ntfs
	puts "Testing ntfs"
	$:.push("#{File.dirname(__FILE__)}/DiskTestCommon/ntfs")
	require 'tc_ntfs_boot'
	require 'tc_ntfs_mft'
	require 'tc_ntfs_index'
	#require 'tc_ntfs_file'
	#require 'tc_ntfs_write' if $miq_test_write #doesn't exist yet.
end

# Ext3 tests.
if miq_test_ext3
	puts "Testing ext3"
	$:.push("#{File.dirname(__FILE__)}/DiskTestCommon/ext3")
	#require 'tc_ext3_cache'
	require 'tc_ext3_superblock'
	require 'tc_ext3_directory'
	require 'tc_ext3_file'
	#require 'tc_ext3_write' if $miq_test_write #doesn't exist yet.
end
