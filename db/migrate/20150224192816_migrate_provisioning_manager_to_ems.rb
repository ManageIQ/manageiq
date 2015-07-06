class MigrateProvisioningManagerToEms < ActiveRecord::Migration
  class ExtManagementSystem < ActiveRecord::Base
    include UuidMixin
    self.inheritance_column = :_type_disabled
  end

  class ProvisioningManager < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class OperatingSystemFlavor < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class CustomizationScript < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  def up
    say_with_time("Migrating provisioning_managers to ext_management_os_flavors") do
      os_flavors = OperatingSystemFlavor.all.group_by(&:provisioning_manager_id)
      scripts    = CustomizationScript.all.group_by(&:provisioning_manager_id)

      ProvisioningManager.all.each do |manager|
        attrs = manager.attributes.except("id")
        attrs["created_on"] = attrs.delete("created_at")
        attrs["updated_on"] = attrs.delete("updated_at")
        ems = ExtManagementSystem.create!(attrs)

        Array(os_flavors.delete(manager.id)).each do |f|
          f.update_attributes!(:provisioning_manager_id => ems.id)
        end

        Array(scripts.delete(manager.id)).each do |s|
          s.update_attributes!(:provisioning_manager_id => ems.id)
        end

        manager.delete
      end
    end
  end

  def down
    say_with_time("Migrating ext_management_os_flavors to provisioning_managers") do
      os_flavors = OperatingSystemFlavor.all.group_by(&:provisioning_manager_id)
      scripts    = CustomizationScript.all.group_by(&:provisioning_manager_id)

      ExtManagementSystem.where(:type => "ProvisioningManagerForeman").each do |ems|
        attrs = ems.attributes
        attrs["created_at"] = attrs.delete("created_on")
        attrs["updated_at"] = attrs.delete("updated_on")
        attrs = attrs.slice(*ProvisioningManager.column_names).except("id")
        manager = ProvisioningManager.create!(attrs)

        Array(os_flavors.delete(ems.id)).each do |f|
          f.update_attributes!(:provisioning_manager_id => manager.id)
        end

        Array(scripts.delete(ems.id)).each do |s|
          s.update_attributes!(:provisioning_manager_id => manager.id)
        end

        ems.delete
      end
    end
  end
end
