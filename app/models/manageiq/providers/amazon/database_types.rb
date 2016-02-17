# DB Instance Types for AWS.  These types are not provided by the AWS SDK, and so
#   are enumerated here manually from the following sources:
#
#   http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.DBInstanceClass.html
module ManageIQ::Providers::Amazon::DatabaseTypes
  # Types that are currently advertised for use
  AVAILABLE_TYPES = {
    "db.t1.micro"    => {
      :name                => "db.t1.micro",
      :family              => "Micro Instances",
      :vcpu                => 1,
      :ecu                 => 1,
      :memory              => 0.615.gigabytes,
      :ebs_optimized       => nil,
      :network_performance => :very_low
    },

    "db.m1.small"    => {
      :name                => "db.m1.small",
      :family              => "Micro Instances",
      :vcpu                => 1,
      :ecu                 => 1,
      :memory              => 1.7.gigabytes,
      :ebs_optimized       => nil,
      :network_performance => :very_low
    },

    "db.m4.large"    => {
      :name                => "db.m4.large",
      :family              => "Standard",
      :vcpu                => 2,
      :ecu                 => 6.5,
      :memory              => 8.gigabytes,
      :ebs_optimized       => 450, # Mbps
      :network_performance => :moderate
    },

    "db.m4.xlarge"   => {
      :name                => "db.m4.xlarge",
      :family              => "Standard",
      :vcpu                => 4,
      :ecu                 => 13,
      :memory              => 16.gigabytes,
      :ebs_optimized       => 750, # Mbps
      :network_performance => :high
    },

    "db.m4.2xlarge"  => {
      :name                => "db.m4.2xlarge",
      :family              => "Standard",
      :vcpu                => 8,
      :ecu                 => 25.5,
      :memory              => 32.gigabytes,
      :ebs_optimized       => 1000, # Mbps
      :network_performance => :high
    },

    "db.m4.4xlarge"  => {
      :name                => "db.m4.4xlarge",
      :family              => "Standard",
      :vcpu                => 16,
      :ecu                 => 53.5,
      :memory              => 64.gigabytes,
      :ebs_optimized       => 2000, # Mbps
      :network_performance => :high
    },

    "db.m4.10xlarge" => {
      :name                => "db.m4.10xlarge",
      :family              => "Standard",
      :vcpu                => 40,
      :ecu                 => 124.5,
      :memory              => 160.gigabytes,
      :ebs_optimized       => 4000, # Mbps
      :network_performance => :very_high
    },

    "db.r3.large"    => {
      :name                => "db.r3.large",
      :family              => "Memory Optimized",
      :vcpu                => 2,
      :ecu                 => 6.5,
      :memory              => 15.gigabytes,
      :ebs_optimized       => nil,
      :network_performance => :moderate
    },

    "db.r3.xlarge"   => {
      :name                => "db.r3.xlarge",
      :family              => "Memory Optimized",
      :vcpu                => 4,
      :ecu                 => 13,
      :memory              => 30.5.gigabytes,
      :ebs_optimized       => 500, # Mbps
      :network_performance => :moderate
    },

    "db.r3.2xlarge"  => {
      :name                => "db.r3.2xlarge",
      :family              => "Memory Optimized",
      :vcpu                => 8,
      :ecu                 => 26,
      :memory              => 61.gigabytes,
      :ebs_optimized       => 1000, # Mbps
      :network_performance => :high
    },

    "db.r3.4xlarge"  => {
      :name                => "db.r3.4xlarge",
      :family              => "Memory Optimized",
      :vcpu                => 16,
      :ecu                 => 52,
      :memory              => 122.gigabytes,
      :ebs_optimized       => 2000, # Mbps
      :network_performance => :high
    },

    "db.r3.8xlarge"  => {
      :name                => "db.r3.8xlarge",
      :family              => "Memory Optimized",
      :vcpu                => 32,
      :ecu                 => 104,
      :memory              => 244.gigabytes,
      :ebs_optimized       => nil,
      :network_performance => :very_high
    },

    "db.t2.micro"    => {
      :name                => "db.t2.micro",
      :family              => "Burst Capable",
      :vcpu                => 1,
      :ecu                 => 1,
      :memory              => 1.gigabytes,
      :ebs_optimized       => nil,
      :network_performance => :low
    },

    "db.t2.small"    => {
      :name                => "db.t2.small",
      :family              => "Burst Capable",
      :vcpu                => 1,
      :ecu                 => 1,
      :memory              => 2.gigabytes,
      :ebs_optimized       => nil,
      :network_performance => :low
    },

    "db.t2.medium"    => {
      :name                => "db.t2.medium",
      :family              => "Burst Capable",
      :vcpu                => 2,
      :ecu                 => 2,
      :memory              => 4.gigabytes,
      :ebs_optimized       => nil,
      :network_performance => :moderate
    },

    "db.t2.large"    => {
      :name                => "db.t2.large",
      :family              => "Burst Capable",
      :vcpu                => 2,
      :ecu                 => 2,
      :memory              => 8.gigabytes,
      :ebs_optimized       => nil,
      :network_performance => :moderate
    }
  }

  DEPRECATED_TYPES = {
    "db.m3.medium"   => {
      :name                => "db.m3.medium",
      :family              => "Standard",
      :vcpu                => 1,
      :ecu                 => 3,
      :memory              => 3.75.gigabytes,
      :ebs_optimized       => nil,
      :network_performance => :moderate
    },

    "db.m3.large"    => {
      :name                => "db.m3.large",
      :family              => "Standard",
      :vcpu                => 2,
      :ecu                 => 6.5,
      :memory              => 7.5.gigabytes,
      :ebs_optimized       => nil,
      :network_performance => :moderate
    },

    "db.m3.xlarge"   => {
      :name                => "db.m3.xlarge",
      :family              => "Standard",
      :vcpu                => 4,
      :ecu                 => 13,
      :memory              => 15.gigabytes,
      :ebs_optimized       => 500, # Mbps
      :network_performance => :high
    },

    "db.m3.2xlarge"  => {
      :name                => "db.m3.2xlarge",
      :family              => "Standard",
      :vcpu                => 8,
      :ecu                 => 26,
      :memory              => 30.gigabytes,
      :ebs_optimized       => 1000, # Mbps
      :network_performance => :high
    },

    "db.m2.xlarge"   => {
      :name                => "db.m2.xlarge",
      :family              => "Memory Optimized",
      :vcpu                => 2,
      :ecu                 => 6.5,
      :memory              => 17.1.gigabytes,
      :ebs_optimized       => nil,
      :network_performance => :moderate
    },

    "db.m2.2xlarge"  => {
      :name                => "db.m2.2xlarge",
      :family              => "Memory Optimized",
      :vcpu                => 4,
      :ecu                 => 23,
      :memory              => 34.2.gigabytes,
      :ebs_optimized       => 500, # Mbps
      :network_performance => :moderate
    },

    "db.m2.4xlarge"  => {
      :name                => "db.m2.4xlarge",
      :family              => "Memory Optimized",
      :vcpu                => 8,
      :ecu                 => 26,
      :memory              => 68.4.gigabytes,
      :ebs_optimized       => 1000, # Mbps
      :network_performance => :high
    },

    "db.cr1.8xlarge" => {
      :name                => "db.cr1.8xlarge",
      :family              => "Memory Optimized",
      :vcpu                => 32,
      :ecu                 => 88,
      :memory              => 244.gigabytes,
      :ebs_optimized       => nil,
      :network_performance => :ver_high
    }
  }

  def self.all
    AVAILABLE_TYPES.values + DEPRECATED_TYPES.values
  end

  def self.names
    AVAILABLE_TYPES.keys + DEPRECATED_TYPES.keys
  end
end
