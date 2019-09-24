require 'miq-extensions'
require 'miq-uuid'

require 'ostruct'
require 'fileutils'
require 'erb'
require 'sync'
require 'sys-uname'

# Need to push the workers path here, since __FILE__ doesn't work
#   correctly in the workers when run as a separate process
$:.push("#{File.dirname(__FILE__)}/workers")

require 'miq-exception'
require 'miq-system'
require 'miq-xml'

require 'vmdb_extensions'
require 'active_record_query_parts'

# Include monkey-patches
$:.push("#{File.dirname(__FILE__)}/patches")
require 'rest_client_patch'
require 'ruport_patch'

APPLIANCE_DATA_VOL = File.directory?("/var/www/miq/vmdb") ? "/var/lib/data" : Rails.root.join("tmp")
MIQ_TEMP           = File.join(APPLIANCE_DATA_VOL, "miq_temp")
FileUtils.mkdir_p(MIQ_TEMP)

module VMDB
  def self.model_loaded?(name)
    begin
      Object.const_get(name.to_sym)
    rescue NameError
      return false
    end
    true
  end
end

require 'vmdb/initializer'
require 'vmdb/util'

require 'vmdb/global_methods'
include Vmdb::GlobalMethods
