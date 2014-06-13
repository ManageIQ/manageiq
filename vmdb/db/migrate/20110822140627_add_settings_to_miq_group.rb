class AddSettingsToMiqGroup < ActiveRecord::Migration
  class MiqGroup < ActiveRecord::Base
    belongs_to :miq_user_role, :class_name => "AddSettingsToMiqGroup::MiqUserRole"
  end

  class MiqUserRole < ActiveRecord::Base
    has_many :miq_groups, :class_name => "AddSettingsToMiqGroup::MiqGroup"
    serialize :settings
  end

  def self.up
    add_column :miq_groups, :settings, :text

    say_with_time("Copying report_menus setting from MiqUserRoles to MiqGroups") do
      MiqGroup.all.each do |g|
        settings = g.miq_user_role.settings
        if settings && settings.has_key?(:report_menus)
          g.update_attribute(:settings, {:report_menus => settings.delete(:report_menus)})
        end
      end
    end

    say_with_time("Removing report_menus setting from MiqUserRoles") do
      MiqUserRole.all.each do |ur|
        settings = ur.settings
        if settings && settings.has_key?(:report_menus)
          settings.delete(:report_menus)
          ur.update_attribute(:settings, settings)
        end
      end
    end

    change_table :miq_reports do |t|
      t.belongs_to  :miq_group
      t.belongs_to  :user
    end
  end

  def self.down
    say_with_time("Copying report_menus setting from MiqGroups to MiqUserRoles") do
      MiqGroup.all.each do |g|
        settings = g.settings
        if settings.respond_to?(:has_key?) && settings.has_key?(:report_menus)
          g.miq_user_role.update_attribute(:settings, g.miq_user_role.settings.merge(:report_menus => settings[:report_menus]))
        end
      end
    end

    remove_column :miq_groups, :settings

    change_table :miq_reports do |t|
      t.remove_belongs_to  :miq_group
      t.remove_belongs_to  :user
    end
  end
end
