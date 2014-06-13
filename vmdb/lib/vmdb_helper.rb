require 'miq-extensions'
require 'miq-uuid'

require 'ostruct'
require 'fileutils'
require 'erb'
require 'sync'
require 'platform'

# Need to push the workers path here, since __FILE__ doesn't work
#   correctly in the workers when run as a separate process
$:.push("#{File.dirname(__FILE__)}/workers")

require 'miq-exception'
require 'miq-system'

$:.push(File.expand_path(File.join(Rails.root, %w{.. lib VMwareWebService})))
require 'vmdb_extensions'
require 'active_record_query_parts'

# Include monkey-patches
$:.push("#{File.dirname(__FILE__)}/patches")
require 'active_support_string_patch'
require 'ruport_patch'

APPLIANCE_DATA_VOL = File.exists?('/var/www/miq/vmdb') ? "/var/lib/data" : File.expand_path(Rails.root + "/tmp")
MIQ_TEMP = File.join(APPLIANCE_DATA_VOL, "miq_temp")
Dir.mkdir(MIQ_TEMP) if !File.exist?(MIQ_TEMP) && File.exist?(APPLIANCE_DATA_VOL)

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

require 'vmdb/config'
require 'vmdb/initializer'
require 'vmdb/miq_appliance'
require 'vmdb/util'

require 'vmdb/global_methods'
include Vmdb::GlobalMethods
