require_migration

class UpdateEmsInMiqAlertStatus < ActiveRecord::Migration[5.0]
  class ExtManagementSystem < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end
  class Vm < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
    belongs_to :ext_management_system, :foreign_key => :ems_id
  end
end

describe UpdateEmsInMiqAlertStatus do
  let(:miq_alert_status_stub) { migration_stub(:MiqAlertStatus) }
  let(:vm_cloud_stub) { migration_stub(:Vm) }
  let(:ext_management_system_stub) { migration_stub(:ExtManagementSystem) }

  migration_context :up do
    it 'it sets ems_id for vms' do
      ext = ext_management_system_stub.create
      vm = vm_cloud_stub.create(:ext_management_system => ext)
      miq_alert_status = miq_alert_status_stub.create!(:resource_type => "VmOrTemplate", :resource_id => vm.id)
      expect(miq_alert_status.ems_id).to be_nil
      migrate
      expect(miq_alert_status.reload.ems_id).to eq(ext.id)
    end
  end
end
