module ManageIQ
  module Providers::SoftLayer
    module Regions
      # From http://www.softlayer.com/data-centers
      # TODO: determine if these should be treated as Regions or some should be
      # moved to AvailabilityZone
      REGIONS = {}.freeze

      def self.all
        REGIONS.values
      end

      def self.names
        REGIONS.keys
      end

      def self.hostnames
        REGIONS_BY_HOSTNAME.keys
      end

      def self.find_by_name(name)
        REGIONS[name]
      end
    end
  end
end
