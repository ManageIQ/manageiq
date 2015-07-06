class AddProvTypeToServiceTemplates < ActiveRecord::Migration
  class ServiceTemplate < ActiveRecord::Base; end;

  def up
    add_column :service_templates, :prov_type, :string

    say_with_time("Setting prov_type for service_templates") do
      ServiceTemplate.where(:service_type => 'atomic').update_all(:prov_type => 'vmware')
    end
  end

  def down
    remove_column :service_templates, :prov_type
  end
end
