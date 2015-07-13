class AddProviderRegionToExtManagementSystems < ActiveRecord::Migration
  class ExtManagementSystem < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    add_column :ext_management_systems, :provider_region, :string

    say_with_time("Moving EmsAmazon regions from hostname to provider_region") do
      ExtManagementSystem.where(:type => "EmsAmazon").update_all("provider_region = hostname")
      ExtManagementSystem.where(:type => "EmsAmazon").update_all(:hostname => nil)
    end
  end

  def down
    say_with_time("Moving EmsAmazon regions from provider_region to hostname") do
      ExtManagementSystem.where(:type => "EmsAmazon").update_all("hostname = provider_region")
    end

    remove_column :ext_management_systems, :provider_region
  end
end
