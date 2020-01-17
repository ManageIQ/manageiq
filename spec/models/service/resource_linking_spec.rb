RSpec.describe Service do
  describe '#add_provider_vms' do
    let(:service)  { FactoryBot.create(:service, :evm_owner => FactoryBot.create(:user)) }
    let(:provider) { FactoryBot.create(:ems_vmware) }
    let(:uid_ems_array) { ["423c9963-378c-813f-1dbd-630e464d59d4", "423cf3e2-e319-3953-993f-fd8513db951d"] }

    it 'raises an error if uid_ems_array is not passed in' do
      expect { service.add_provider_vms(provider, []) }.to raise_error(RuntimeError, "no uid_ems_array defined for linking to service")
    end

    it 'creates a Service::LinkingWorkflow job' do
      expect(Service::LinkingWorkflow).to receive(:create_job) do |args|
        expect(args).to match(hash_including(:target_class => provider.class.name, :target_id => provider.id))
        expect(args).to match(hash_including(:uid_ems_array => array_including(uid_ems_array)))
      end.and_return(double(:signal => :start))
      service.add_provider_vms(provider, uid_ems_array)
    end
  end
end
