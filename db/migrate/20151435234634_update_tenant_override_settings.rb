require 'ancestry'

class UpdateTenantOverrideSettings < ActiveRecord::Migration
  class Tenant < ActiveRecord::Base
    has_ancestry
  end

  def up
    say_with_time "updating root_tenant to load from configurations" do
      Tenant.where(:ancestry => nil).update_all(:use_config_for_attributes => true)
    end
  end
end
