__lib_dir__ = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH.unshift __lib_dir__ unless $LOAD_PATH.include?(__lib_dir__)

require 'openstack_handle/handle'
require 'fog'
require 'openstack_handle/compute_delegate'
require 'openstack_handle/identity_delegate'
require 'openstack_handle/network_delegate'
require 'openstack_handle/image_delegate'
require 'openstack_handle/volume_delegate'
require 'openstack_handle/storage_delegate'
require 'openstack_handle/metering_delegate'
