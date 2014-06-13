class AddSettingsToMiqUserRoles < ActiveRecord::Migration
  def self.up
    add_column    :miq_user_roles,    :settings,    :text
  end

  def self.down
    remove_column :miq_user_roles,    :settings
  end
end
