require_migration

describe UpdateEmsInMiqAlertStatus do
  let(:miq_alert_status_stub) { migration_stub(:MiqAlertStatus) }

  migration_context :up do
    it 'it sets ems_id for vms' do
      ext = FactoryGirl.create(:ext_management_system)
      vm = FactoryGirl.create(:vm_cloud, :ext_management_system => ext)
      miq_alert_status = miq_alert_status_stub.create!(:resource_type => "VmOrTemplate", :resource_id => vm.id)
      expect(miq_alert_status.ems_id).to be_nil
      migrate
      expect(miq_alert_status.reload.ems_id).to eq(ext.id)
    end
  end
end
