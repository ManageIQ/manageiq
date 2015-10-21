class TenantCfgNotNil < ActiveRecord::Migration
  class Tenant < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    Tenant.where(:use_config_for_attributes => nil).update_all(:use_config_for_attributes => false)
  end
end
