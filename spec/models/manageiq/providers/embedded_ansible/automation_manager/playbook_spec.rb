describe ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Playbook do
  let(:manager) { FactoryGirl.create(:embedded_automation_manager_ansible) }
  subject { FactoryGirl.create(:embedded_playbook, :manager => manager) }

  describe '#run' do
    it 'delegates request to playbook runner' do
      double_return = double(:signal => nil, :miq_task => double(:id => 'tid'))
      expect(ManageIQ::Providers::EmbeddedAnsible::AutomationManager::PlaybookRunner)
        .to receive(:create_job).with(hash_including(:playbook_id => subject.id, :userid => 'system')).and_return(double_return)
      expect(subject.run({})).to eq('tid')
    end
  end

  describe '#raw_create_job_template' do
    it 'delegates request to job template raw creation' do
      options = {:inventory => 'inv', :extra_vars => {'a' => 'x'} }
      option_matcher = hash_including(
        :inventory  => 'inv',
        :extra_vars => '{"a":"x"}',
        :playbook   => subject.name,
        :project    => 'mref'
      )

      allow(subject).to receive(:configuration_script_source).and_return(double(:manager_ref => 'mref'))
      expect(ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScript)
        .to receive(:raw_create_in_provider).with(instance_of(manager.class), option_matcher)
      subject.raw_create_job_template(options)
    end
  end
end
