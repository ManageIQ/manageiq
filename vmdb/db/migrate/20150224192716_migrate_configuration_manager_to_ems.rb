class MigrateConfigurationManagerToEms < ActiveRecord::Migration
  class ExtManagementSystem < ActiveRecord::Base
    include UuidMixin
    self.inheritance_column = :_type_disabled
  end

  class ConfigurationManager < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class ConfiguredSystem < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class ConfigurationProfile < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  def up
    say_with_time("Migrating configuration_managers to ext_management_systems") do
      systems  = ConfiguredSystem.all.group_by(&:configuration_manager_id)
      profiles = ConfigurationProfile.all.group_by(&:configuration_manager_id)

      ConfigurationManager.all.each do |manager|
        attrs = manager.attributes.except("id")
        attrs["created_on"] = attrs.delete("created_at")
        attrs["updated_on"] = attrs.delete("updated_at")
        ems = ExtManagementSystem.create!(attrs)

        Array(systems.delete(manager.id)).each do |s|
          s.update_attributes!(:configuration_manager_id => ems.id)
        end

        Array(profiles.delete(manager.id)).each do |p|
          p.update_attributes!(:configuration_manager_id => ems.id)
        end

        manager.delete
      end
    end
  end

  def down
    say_with_time("Migrating ext_management_systems to configuration_managers") do
      systems  = ConfiguredSystem.all.group_by(&:configuration_manager_id)
      profiles = ConfigurationProfile.all.group_by(&:configuration_manager_id)

      ExtManagementSystem.where(:type => "ConfigurationManagerForeman").each do |ems|
        attrs = ems.attributes
        attrs["created_at"] = attrs.delete("created_on")
        attrs["updated_at"] = attrs.delete("updated_on")
        attrs = attrs.slice(*ConfigurationManager.column_names).except("id")
        manager = ConfigurationManager.create!(attrs)

        Array(systems.delete(ems.id)).each do |s|
          s.update_attributes!(:configuration_manager_id => manager.id)
        end

        Array(profiles.delete(ems.id)).each do |p|
          p.update_attributes!(:configuration_manager_id => manager.id)
        end

        ems.delete
      end
    end
  end
end
