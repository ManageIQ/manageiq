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
        }
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
