describe ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Job do
  let(:job) { FactoryBot.create(:embedded_ansible_job) }

  before do
    region = MiqRegion.seed
    allow(region).to receive(:role_active?).with("embedded_ansible").and_return(role_enabled)
    allow(MiqRegion).to receive(:my_region).and_return(region)
  end

  context 'when embedded_ansible role is enabled' do
    let(:role_enabled) { true }

    it_behaves_like 'ansible job'
  end

  context 'when embedded_ansible role is disabled' do
    describe '#raw_stdout_via_worker' do
      let(:role_enabled) { false }

      it 'returns an error message' do
        taskid = job.raw_stdout_via_worker('user')
        expect(MiqTask.find(taskid)).to have_attributes(
          :message => 'Cannot get standard output of this playbook because the embedded Ansible role is not enabled',
          :status  => 'Error'
        )
      end
    end
  end
end
