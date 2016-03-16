module ManageIQ
  module Providers::Azure
    module Regions
      REGIONS = {
        "westus" => {
          :name        => "westus",
          :description => _("US West"),
        },
        "eastus" => {
          :name        => "eastus",
          :description => _("US East"),
        },
        "australiaeast" => {
          :name        => "australiaeast",
          :description => _("Australia East"),
        },
        "australiasoutheast" => {
          :name        => "australiasoutheast",
          :description => _("Australia South East"),
        },
        "centralus" => {
          :name        => "centralus",
          :description => _("Central US"),
        },
        "eastus2" => {
          :name        => "eastus2",
          :description => _("East US2"),
        },
        "northcentralus" => {
          :name        => "northcentralus",
          :description => _("North Central US"),
        },
        "southcentralus" => {
          :name        => "southcentralus",
          :description => _("South Central US"),
        },
        "northeurope" => {
          :name        => "northeurope",
          :description => _("North Europe"),
        },
        "westeurope" => {
          :name        => "westeurope",
          :description => _("West Europe"),
        },
        "eastasia" => {
          :name        => "eastasia",
          :description => _("East Asia"),
        },
        "southeastasia" => {
          :name        => "southeastasia",
          :description => _("South East Asia"),
        },
        "japaneast" => {
          :name        => "japaneast",
          :description => _("Japan East"),
        },
        "japanwest" => {
          :name        => "japanwest",
          :description => _("Japan West"),
        },
        "brazilsouth" => {
          :name        => "brazilsouth",
          :description => _("Brazil South"),
        },
        "westindia" => {
          :name        => "westindia",
          :description => _("West India"),
        },
        "southindia" => {
          :name        => "southindia",
          :description => _("South India"),
        },
        "centralindia" => {
          :name        => "centralindia",
          :description => _("Central India"),
        },
        "westus(partner)" => {
          :name        => "westus(partner)",
          :description => _("West US (Partner)"),
        },
        "eastus2(stage)" => {
          :name        => "eastus2(stage)",
          :description => _("East US2 (Stage)"),
        },
        "northcentralus(stage)" => {
          :name        => "northcentralus(stage)",
          :description => _("North Central US (Stage)"),
        },
        "global" => {
          :name        => "global",
          :description => _("Global"),
        },
        "msftwestus" => {
          :name        => "msftwestus",
          :description => _("MSFT West US"),
        },
        "msfteastus" => {
          :name        => "msfteastus",
          :description => _("MSFT East US"),
        },
        "msfteastasia" => {
          :name        => "msfteastasia",
          :description => _("MSFT East Asia"),
        },
        "msftnortheurope" => {
          :name        => "msftnortheurope",
          :description => _("MSFT North Europe"),
        },
        "eastasia(stage)" => {
          :name        => "eastasia(stage)",
          :description => _("East Asia (Stage)"),
        },
        "centralus(stage)" => {
          :name        => "centralus(stage)",
          :description => _("Central US (Stage)"),
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
