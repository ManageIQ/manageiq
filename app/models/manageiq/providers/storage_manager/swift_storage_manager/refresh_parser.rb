#
#
#
module ManageIQ::Providers
  class StorageManager::SwiftStorageManager::RefreshParser < ManageIQ::Providers::CloudManager::RefreshParser
    include Vmdb::Logging

    attr_accessor :data, :parser

    def self.ems_inv_to_hashes(ems, options = nil)
      new(ems, options).ems_inv_to_hashes
    end

    def initialize(ems, options = nil)
      @ems               = ems
      @data              = {}
    end

    def self.get_parser(ems, options = nil)
    end

    def ems_inv_to_hashes
      log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data for EMS name: [#{@ems.name}] id: [#{@ems.id}]"

      $fog_log.info("#{log_header}...")
      get_object_store

      $fog_log.info("#{log_header}...Complete")

    end

  end
end
