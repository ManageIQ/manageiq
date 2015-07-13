class AddCloudToVms < ActiveRecord::Migration
  class VmOrTemplate < ActiveRecord::Base
    self.table_name = 'vms'
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    add_column :vms, :cloud, :boolean

    say_with_time("Updating Cloud in Vms") do
      VmOrTemplate.where("type IN (?)", ['VmAmazon', 'VmOpenstack', 'TemplateAmazon', 'TemplateOpenstack'])
                  .update_all(:cloud => true)
      VmOrTemplate.where("type NOT IN (?)", ['VmAmazon', 'VmOpenstack', 'TemplateAmazon', 'TemplateOpenstack'])
                  .update_all(:cloud => false)
    end
  end

  def down
    remove_column :vms, :cloud
  end
end
