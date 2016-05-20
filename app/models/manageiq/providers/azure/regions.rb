module ManageIQ
  module Providers::Azure
    module Regions
      REGIONS = {
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
          :description => _("US East"),
        },
        "eastus2" => {
          :name        => "eastus2",
          :description => _("East US2"),
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
        "westeurope" => {
          :name        => "westeurope",
          :description => _("West Europe"),
        },
        "westus" => {
          :name        => "westus",
          :description => _("US West"),
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
