class UpdateTenantOverrideSettings < ActiveRecord::Migration
  include MigrationHelper

  class Tenant < ActiveRecord::Base; end

  def up
    return if previously_migrated_as?("20151435234634")
    say_with_time "updating root_tenant to load from configurations" do
      Tenant.where(:ancestry => nil).update_all(:use_config_for_attributes => true)
    end
  end
end
