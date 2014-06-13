class FixVmOrTemplateAlerts < ActiveRecord::Migration
  class VmOrTemplate < ActiveRecord::Base
    self.table_name = 'vms'
    self.inheritance_column = :_type_disabled # disable STI
  end

  def update_and_save_alert(alert, name_split, new_scope)
    name_split[3] = new_scope
    alert.name = name_split.join("/")
    alert.save!
  end
  def up
    # look for MiqTemplate alerts from v4 (namespaced /vm/)
    Tag.where("name like '/miq_alert_set/assigned_to/vm/%'").each do |alert|
      name_split = alert.name.split("/")
      if name_split[4] == "id"
        vm_or_template = VmOrTemplate.find(name_split.last.to_i)
        # if there are any template alerts, change namespace
        if vm_or_template.type.downcase.starts_with?("template")
          update_and_save_alert(alert, name_split, "miq_template")
        end
      end
    end

    # look for Vm or Template alerts from v5 (namespaced /vm_or_template)
    Tag.where("name like '/miq_alert_set/assigned_to/vm_or_template/%'").each do |alert|
      name_split = alert.name.split("/")
      if name_split[4] == "id"
        vm_or_template = VmOrTemplate.find(name_split.last.to_i)
        update_and_save_alert(alert, name_split,
          vm_or_template.type.downcase.starts_with?("vm") ? "vm" : "miq_template")
      elsif name_split[4].starts_with?("tag")
        update_and_save_alert(alert, name_split, "vm")
      end
    end
  end

  def down
    # do nothing on down -- this change is irreversible
  end
end
