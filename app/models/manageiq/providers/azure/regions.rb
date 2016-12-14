module ManageIQ
  module Providers::Azure
    module Regions
      REGIONS = {
        "australiaeast" => {
          :name        => "australiaeast",
          :description => _("Australia East"),
        },
        "australiasoutheast" => {
          :name        => "australiasoutheast",
          :description => _("Australia Southeast"),
        },
        "brazilsouth" => {
          :name        => "brazilsouth",
          :description => _("Brazil South"),
        },
        "canadacentral" => {
          :name        => "canadacentral",
          :description => _("Canada Central"),
        },
        "canadaeast" => {
          :name        => "canadaeast",
          :description => _("Canada East"),
        },
        "centralindia" => {
          :name        => "centralindia",
          :description => _("Central India"),
        },
        "centralus" => {
          :name        => "centralus",
          :description => _("Central US"),
        },
        "eastasia" => {
          :name        => "eastasia",
          :description => _("East Asia"),
        },
        "eastus" => {
          :name        => "eastus",
          :description => _("East US"),
        },
        "eastus2" => {
          :name        => "eastus2",
          :description => _("East US 2"),
        },
        "japaneast" => {
          :name        => "japaneast",
          :description => _("Japan East"),
        },
        "japanwest" => {
          :name        => "japanwest",
          :description => _("Japan West"),
        },
        "northcentralus" => {
          :name        => "northcentralus",
          :description => _("North Central US"),
        },
        "northeurope" => {
          :name        => "northeurope",
          :description => _("North Europe"),
        },
        "southcentralus" => {
          :name        => "southcentralus",
          :description => _("South Central US"),
        },
        "southeastasia" => {
          :name        => "southeastasia",
          :description => _("South East Asia"),
        },
        "southindia" => {
          :name        => "southindia",
          :description => _("South India"),
        },
        "usgovarizona" => {
          :name        => "usgovarizona",
          :description => _("US Gov Arizona"),
        },
        "usgoviowa" => {
          :name        => "usgoviowa",
          :description => _("US Gov Iowa"),
        },
        "usgovtexas" => {
          :name        => "usgovtexas",
          :description => _("US Gov Texas"),
        },
        "usgovvirginia" => {
          :name        => "usgovvirginia",
          :description => _("US Gov Virginia"),
        },
        "westeurope" => {
          :name        => "westeurope",
          :description => _("West Europe"),
        },
        "westindia" => {
          :name        => "westindia",
          :description => _("West India"),
        },
        "westcentralus" => {
          :name        => "westcentralus",
          :description => _("West Central US"),
        },
        "westus" => {
          :name        => "westus",
          :description => _("West US"),
        },
        "westus2" => {
          :name        => "westus2",
          :description => _("West US 2"),
        },
      }

      def self.regions
        REGIONS.except(*Array(Settings.ems.ems_azure.try!(:disabled_regions)))
      end

      def self.all
        regions.values
      end

      def self.names
        regions.keys
      end

      def self.find_by_name(name)
        regions[name]
      end
    end
  end
end
