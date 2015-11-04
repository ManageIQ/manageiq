module ManageIQ
  module Providers::Azure
    module Regions
      REGIONS = {
        "westus" => {
          :name        => "westus",
          :description => "US West",
        },
        "eastus" => {
          :name        => "eastus",
          :description => "US East",
        },
        "australiaeast" => {
          :name        => "australiaeast",
          :description => "Australia East",
        },
        "australiasoutheast" => {
          :name        => "australiasoutheast",
          :description => "Australia South East",
        },
        "centralus" => {
          :name        => "centralus",
          :description => "Central US",
        },
        "eastus2" => {
          :name        => "eastus2",
          :description => "East US2",
        },
        "northcentralus" => {
          :name        => "northcentralus",
          :description => "North Central US",
        },
        "southcentralus" => {
          :name        => "southcentralus",
          :description => "South Central US",
        },
        "northeurope" => {
          :name        => "northeurope",
          :description => "North Eurpoe",
        },
        "westeurope" => {
          :name        => "westeurope",
          :description => "West Eurpoe",
        },
        "eastasia" => {
          :name        => "eastasia",
          :description => "East Asia",
        },
        "southeastasia" => {
          :name        => "southeastasia",
          :description => "South East Asia",
        },
        "japaneast" => {
          :name        => "japaneast",
          :description => "Japan East",
        },
        "japanwest" => {
          :name        => "japanwest",
          :description => "Japan West",
        },
        "brazilsouth" => {
          :name        => "brazilsouth",
          :description => "Brazil South",
        },
        "westindia" => {
          :name        => "westindia",
          :description => "West India",
        },
        "southindia" => {
          :name        => "southindia",
          :description => "South India",
        },
        "centralindia" => {
          :name        => "centralindia",
          :description => "Central India",
        },
        "westus(partner)" => {
          :name        => "westus(partner)",
          :description => "West US (Partner)",
        },
        "eastus2(stage)" => {
          :name        => "eastus2(stage)",
          :description => "East US2 (Stage)",
        },
        "northcentralus(stage)" => {
          :name        => "northcentralus(stage)",
          :description => "North Central US (Stage)",
        },
        "global" => {
          :name        => "global",
          :description => "Global",
        },
        "msftwestus" => {
          :name        => "msftwestus",
          :description => "MSFT West US",
        },
        "msfteastus" => {
          :name        => "msfteastus",
          :description => "MSFT East US",
        },
        "msfteastasia" => {
          :name        => "msfteastasia",
          :description => "MSFT East Asia",
        },
        "msftnortheurope" => {
          :name        => "msftnortheurope",
          :description => "MSFT North Europe",
        },
        "eastasia(stage)" => {
          :name        => "eastasia(stage)",
          :description => "East Asia (Stage)",
        },
        "centralus(stage)" => {
          :name        => "centralus(stage)",
          :description => "Central US (Stage)",
        },
      }

      def self.all
        REGIONS.values
      end

      def self.names
        REGIONS.keys
      end

      def self.find_by_name(name)
        REGIONS[name]
      end
    end
  end
end
