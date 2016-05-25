module ManageIQ
  module Providers::Softlayer
    module Regions
      # From http://www.softlayer.com/data-centers
      # TODO: determine if these should be treated as Regions or some should be
      # moved to AvailabilityZone
      REGIONS = {
        "ams01" => {
          :name        => "ams01",
          :description => "Amsterdam 01, The Netherlands",
        },
        "ams03" => {
          :name        => "ams03",
          :description => "Amsterdam 03, The Netherlands",
        },
        "che01" => {
          :name        => "che01",
          :description => "Chennai, India",
        },
        "dal01" => {
          :name        => "dal01",
          :description => "Dallas 01, USA",
        },
        "dal02" => {
          :name        => "dal02",
          :description => "Dallas 02, USA",
        },
        "dal05" => {
          :name        => "dal05",
          :description => "Dallas 05, USA",
        },
        "dal06" => {
          :name        => "dal06",
          :description => "Dallas 06, USA",
        },
        "dal07" => {
          :name        => "dal07",
          :description => "Dallas 07, USA",
        },
        "dal09" => {
          :name        => "dal09",
          :description => "Dallas 09, USA",
        },
        "fra02" => {
          :name        => "fra02",
          :description => "Frankfurt, Germany",
        },
        "hkg02" => {
          :name        => "hkg02",
          :description => "Hong Kong, China",
        },
        "hou02" => {
          :name        => "hou02",
          :description => "Houston, USA",
        },
        "lon02" => {
          :name        => "lon02",
          :description => "London, England",
        },
        "mel01" => {
          :name        => "mel01",
          :description => "Melbourne, Australia",
        },
        "mil01" => {
          :name        => "mil01",
          :description => "Milan, Italy",
        },
        "mon01" => {
          :name        => "mon01",
          :description => "Montreal, Canada",
        },
        "par01" => {
          :name        => "par01",
          :description => "Paris, France",
        },
        "mex01" => {
          :name        => "mex01",
          :description => "Querétaro, Mexico",
        },
        "sjc01" => {
          :name        => "sjc01",
          :description => "San Jose 01, USA",
        },
        "sjc03" => {
          :name        => "sjc03",
          :description => "San Jose 03, USA",
        },
        "sao01" => {
          :name        => "sao01",
          :description => "Sao Paulo, Brazil",
        },
        "sea01" => {
          :name        => "sea01",
          :description => "Seattle, USA",
        },
        "sng01" => {
          :name        => "sng01",
          :description => "Singapore, Singapore",
        },
        "syd01" => {
          :name        => "syd01",
          :description => "Sydney, Australia",
        },
        "tok02" => {
          :name        => "tok02",
          :description => "Tokyo, Japan",
        },
        "tor01" => {
          :name        => "tor01",
          :description => "Toronto, Canada",
        },
        "wdc01" => {
          :name        => "wdc01",
          :description => "Washington, D.C. 01, USA",
        },
        "wdc04" => {
          :name        => "wdc04",
          :description => "Washington, D.C. 04, USA",
        }
      }.freeze

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
