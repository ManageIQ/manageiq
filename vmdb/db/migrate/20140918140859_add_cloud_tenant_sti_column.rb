class AddCloudTenantStiColumn < ActiveRecord::Migration
  class CloudTenant < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    add_column :cloud_tenants, :type, :string

    say_with_time("Default cloud tenant type value to CloudTenantOpenstack") do
      CloudTenant.update_all(:type => "CloudTenantOpenstack")
    end
  end

  def down
    remove_column :cloud_tenants, :type
  end
end
