require 'yaml'

begin
  lib_files = %w(miq_queue/constants miq_queue/format_methods miq_queue/put_methods)
  lib_files.each { |req| require req }
rescue LoadError
  # Looks like lib isn't in the path, so just load things the hard way
  lib_files.each { |req| require File.expand_path("../../app/models/#{req}", File.dirname(__FILE__)) }
end

# FIXME:  NEEDS MAJOR REFACTORING
#
# We should be sharing methods from app/models/miq_queue.rb, but copy-pasta for
# now for POC.  Fix before MERGE
module Mini
  # class SettingsChange < ActiveRecord::Base
  # end

  class MiqQueue < ActiveRecord::Base
    self.table_name = "miq_queue"

    include MiqQueueConstants

    extend MiqQueueFormatMethods
    extend MiqQueuePutMethods


    def data
      msg_data && Marshal.load(msg_data)
    end

    def data=(value)
      self.msg_data = Marshal.dump(value)
    end

    def self.zone_class
      ::Mini::Zone
    end
    private_class_method :zone_class
  end

  # class MiqRegion < ActiveRecord::Base
  #   def self.my_region(use_cache=false)
  #     find_by(:region => discover_my_region_number)
  #   end

  #   def self.id_to_region(id)
  #     id.to_i / 1_000_000_000_000
  #   end

  #   def self.region_number_from_sequence
  #     return unless connection.data_source_exists?("miq_databases")
  #     id_to_region(connection.select_value("SELECT last_value FROM miq_databases_id_seq"))
  #   end

  #   def self.discover_my_region_number
  #     # region_file = File.join(Rails.root, "REGION")
  #     # region_num = File.read(region_file) if File.exist?(region_file)
  #     region_num ||= ENV.fetch("REGION", nil)
  #     region_num ||= region_number_from_sequence
  #     region_num.to_i
  #   end
  # end

  # class MiqServer < ActiveRecord::Base
  #   def miq_region
  #     MiqRegion.my_region
  #   end
  # end

  # class MiqServer < ActiveRecord::Base
  #   def miq_region
  #     MiqRegion.my_region
  #   end
  # end

  class Zone < ActiveRecord::Base
    # Simplified form of app/models/zone.rb:86 since we never do the lookup and
    # always pass in the options[:zone]
    def self.determine_queue_zone(options)
      options[:zone] # return specified zone including nil (aka ANY zone)
    end
  end
end

# FIXME: HACK
# SettingsChange = Mini::SettingsChange
# MiqServer = Mini::MiqServer
