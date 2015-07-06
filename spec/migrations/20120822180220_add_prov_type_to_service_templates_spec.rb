require "spec_helper"
require Rails.root.join("db/migrate/20120822180220_add_prov_type_to_service_templates.rb")

describe AddProvTypeToServiceTemplates do
  migration_context :up do
    let(:service_template)      { migration_stub(:ServiceTemplate) }

    it "Setting prov_type for service_templates" do
      changed   = service_template.create!(:service_type => 'atomic')
      unchanged = service_template.create!(:service_type => 'not_atomic')

      migrate

      changed.reload.prov_type.should   == 'vmware'

      unchanged.reload
      unchanged.prov_type.should be_nil
      unchanged.service_type.should == 'not_atomic'
    end
  end
end
