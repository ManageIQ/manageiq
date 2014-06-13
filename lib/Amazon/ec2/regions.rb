# The aws-sdk gem can get us this information, however it talks to EC2 to get it.
# For cases where we don't yet want to contact EC2, this information is hardcoded.

module Amazon
  module EC2
    module Regions
      # From http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region
      REGIONS = {
        "us-east-1" => {
          :name        => "us-east-1",
          :hostname    => "ec2.us-east-1.amazonaws.com",
          :description => "US East (Northern Virginia)",
        },
        "us-west-1" => {
          :name        => "us-west-1",
          :hostname    => "ec2.us-west-1.amazonaws.com",
          :description => "US West (Northern California)",
        },
        "us-west-2" => {
          :name        => "us-west-2",
          :hostname    => "ec2.us-west-2.amazonaws.com",
          :description => "US West (Oregon)",
        },
        "eu-west-1" => {
          :name        => "eu-west-1",
          :hostname    => "ec2.eu-west-1.amazonaws.com",
          :description => "EU (Ireland)",
        },
        "ap-southeast-1" => {
          :name        => "ap-southeast-1",
          :hostname    => "ec2.ap-southeast-1.amazonaws.com",
          :description => "Asia Pacific (Singapore)",
        },
        "ap-southeast-2" => {
          :name        => "ap-southeast-2",
          :hostname    => "ec2.ap-southeast-2.amazonaws.com",
          :description => "Asia Pacific (Sydney)",
        },
        "ap-northeast-1" => {
          :name        => "ap-northeast-1",
          :hostname    => "ec2.ap-northeast-1.amazonaws.com",
          :description => "Asia Pacific (Tokyo)",
        },
        "sa-east-1" => {
          :name        => "sa-east-1",
          :hostname    => "ec2.sa-east-1.amazonaws.com",
          :description => "South America (Sao Paulo)",
        },
        "us-gov-west-1" => {
          :name        => "us-gov-west-1",
          :hostname    => "ec2.us-gov-west-1.amazonaws.com",
          :description => "GovCloud (US)",
        }
      }

      REGIONS_BY_HOSTNAME =
        REGIONS.values.each_with_object({}) do |v, h|
          h[v[:hostname]] = v
        end

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

      def self.find_by_hostname(hostname)
        REGIONS_BY_HOSTNAME[hostname]
      end
    end
  end
end
