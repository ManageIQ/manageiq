require_migration

describe AddHawkularKeysToMiqAlerts do
  let(:miq_alert_stub) { migration_stub(:MiqAlert) }
  let(:miq_ems_stub) { migration_stub(:ExtManagementSystem) }

  migration_context :up do
    it "generates legacy hawkular keys" do
      miq_alert_stub.create!(:id => '100', :db => 'MiddlewareServer', :description => 'Hawkular')
      miq_alert_stub.create!(:id => '200', :db => 'Vm', :description => 'Not Hawkular')

      miq_ems_stub.create!(:id => 1001, :type => 'ManageIQ::Providers::Hawkular::MiddlewareManager', :name => 'Hawkular')
      miq_ems_stub.create!(:id => 1002, :type => 'SomethingElse', :name => 'Not Hawkular')

      migrate

      expect(miq_alert_stub.count).to eq(2)
      expect(miq_alert_stub.find(100).hawkular_keys).to eq('ems_1001' => 'MiQ-100')
      expect(miq_alert_stub.find(200).hawkular_keys).to be_blank
    end
  end
end
