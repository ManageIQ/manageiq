describe ManageIQ::Providers::Redhat::InfraManager::MetricsCapture do
  require 'ovirt_metrics'
  context '#perf_collect_metrics' do
    let(:ems) { FactoryGirl.create(:ems_redhat_with_metrics_authentication) }
    let(:host) { FactoryGirl.create(:host_redhat, :ems_id => ems.id) }
    let(:start_time) { 4.hours.ago }
    it 'collects historical metric data according to the value of historical_start_time' do
      allow(Metric::Capture).to receive(:historical_start_time).and_return(start_time)
      allow(OvirtMetrics).to receive(:establish_connection).and_return(true)
      allow_any_instance_of(ManageIQ::Providers::Redhat::InfraManager).to receive(:history_database_name)
                                                                      .and_return('stuff')
      expect(OvirtMetrics).to receive(:host_realtime).with(host.uid_ems, start_time, nil)
      host.perf_collect_metrics("realtime")
    end
  end
end
