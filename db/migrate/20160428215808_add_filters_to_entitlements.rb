class AddFiltersToEntitlements < ActiveRecord::Migration[5.0]
  include MigrationHelper

  class Entitlement < ActiveRecord::Base; end

  def change
    return if previously_migrated_as?("20160414123914")

    add_column :entitlements, :filters, :text

    # HACK, this shouldn't be required, figure out why. :cry:
    # Without this, migrate fails when you go from "latest schema" down to:
    # 20160317194215_remove_miq_user_role_from_miq_groups.rb
    Entitlement.reset_column_information
  end
end
