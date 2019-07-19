describe ManageIQ::Providers::EmbeddedAnsible::AutomationManager::PlaybookRunner do
  let(:manager)  { FactoryBot.create(:embedded_automation_manager_ansible) }
  let(:playbook) { FactoryBot.create(:embedded_playbook, :manager => manager) }
  subject { ManageIQ::Providers::EmbeddedAnsible::AutomationManager::PlaybookRunner.create_job(options.merge(:playbook_id => playbook.id)) }

  describe '#start' do
    let(:options) { {:hosts => 'localhost'} }

    it 'moves on to create_job_template' do
      expect(subject).to receive(:queue_signal).with(:create_job_template, :deliver_on => nil)
      subject.start
    end
  end

  describe '#current_job_timeout' do
    context 'timeout set in options' do
      let(:options) { {:execution_ttl => 50} }

      it 'uses customized timeout value' do
        expect(subject.current_job_timeout).to eq(3000)
      end
    end

    context 'timeout not set in options' do
      let(:options) { {} }

      it 'uses default timeout value' do
        expect(subject.current_job_timeout).to eq(described_class::DEFAULT_EXECUTION_TTL * 60)
      end
    end

    context 'timeout is blank in options' do
      let(:options) { {:execution_ttl => ""} }

      it 'uses default timeout value' do
        expect(subject.current_job_timeout).to eq(described_class::DEFAULT_EXECUTION_TTL * 60)
      end
    end
  end

  describe '#create_job_template' do
    before { allow(subject).to receive(:playbook).and_return(playbook) }
    let(:options) { {:playbook_id => playbook.id, :inventory => 'inv1'} }

    context 'options are enough to cretate job template' do
      it 'creates a job template and moves on to launch_ansible_tower_job' do
        allow(playbook).to receive(:raw_create_job_template).and_return(double(:id => 'jt_ref'))
        expect(subject).to receive(:signal).with(:launch_ansible_tower_job)
        subject.create_job_template
        expect(subject.options).to include(:job_template_ref => 'jt_ref')
      end
    end

    context 'error is raised' do
      it 'moves on to post_ansible_run' do
        allow(playbook).to receive(:raw_create_job_template).and_raise("can't complete the request")
        expect(subject).to receive(:signal).with(:post_ansible_run, "can't complete the request", "error")
        subject.create_job_template
      end
    end
  end

  describe '#launch_ansible_tower_job' do
    let(:options) { {:job_template_ref => 'jt1'} }

    context 'job template is ready' do
      it 'launches a job and moves on to poll_ansible_tower_job_status' do
        expect(ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Job).to receive(:create_job)
          .with(an_instance_of(ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScript), :hosts => ["localhost"])
          .and_return(double(:id => 'jb1'))
        expect(subject).to receive(:queue_signal).with(:poll_ansible_tower_job_status, kind_of(Integer), kind_of(Hash))
        subject.launch_ansible_tower_job
        expect(subject.options[:tower_job_id]).to eq('jb1')
      end
    end

    context 'error is raised' do
      it 'moves on to post_ansible_run' do
        allow(ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Job).to receive(:create_job).and_raise("can't complete the request")
        expect(subject).to receive(:signal).with(:post_ansible_run, "can't complete the request", "error")
        subject.launch_ansible_tower_job
      end
    end

    context 'with launch options' do
      let(:options) { {:job_template_ref => 'jt1', :extra_vars => {:thing => "stuff"}, :verbosity => "4", :become_enabled => true} }
      it 'passes them to the job' do
        expect(ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Job).to receive(:create_job)
          .with(an_instance_of(ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScript), :hosts => ["localhost"], :extra_vars => {:thing => "stuff"}, :verbosity => "4", :become_enabled => true)
          .and_return(double(:id => 'jb1'))
        expect(subject).to receive(:queue_signal)
        subject.launch_ansible_tower_job
      end
    end

    context 'with a host list' do
      let(:options) { {:job_template_ref => 'jt1', :hosts => "192.0.2.0, , 192.0.2.1, 192.0.2.2  ,,,"} }
      it 'passes them to the job' do
        expect(ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Job).to receive(:create_job)
          .with(an_instance_of(ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScript), :hosts => %w[192.0.2.0 192.0.2.1 192.0.2.2])
          .and_return(double(:id => 'jb1'))
        expect(subject).to receive(:queue_signal)
        subject.launch_ansible_tower_job
      end
    end

    context 'with credentials' do
      let(:cloud_credential)   { FactoryBot.create(:embedded_ansible_amazon_credential) }
      let(:machine_credential) { FactoryBot.create(:embedded_ansible_machine_credential) }
      let(:network_credential) { FactoryBot.create(:embedded_ansible_network_credential) }
      let(:vault_credential)   { FactoryBot.create(:embedded_ansible_vault_credential) }

      let(:options) do
        {
          :cloud_credential_id   => cloud_credential.id,
          :credential_id         => machine_credential.id,
          :network_credential_id => network_credential.id,
          :vault_credential_id   => vault_credential.id
        }
      end

      it 'passes them to the job' do
        expected_options = {
          :hosts              => ["localhost"],
          :cloud_credential   => cloud_credential.native_ref,
          :credential         => machine_credential.native_ref,
          :network_credential => network_credential.native_ref,
          :vault_credential   => vault_credential.native_ref
        }
        expect(ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Job).to receive(:create_job)
          .with(an_instance_of(ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScript), expected_options)
          .and_return(double(:id => 'jb1'))
        expect(subject).to receive(:queue_signal)
        subject.launch_ansible_tower_job
      end
    end
  end

  describe '#poll_ansible_tower_job_status' do
    let(:options) { {:tower_job_id => 'jb1'} }

    context 'tower job is still running' do
      before { allow(subject).to receive(:ansible_job).and_return(double(:raw_status => double(:completed? => false))) }

      it 'requeues for later poll' do
        expect(subject).to receive(:queue_signal).with(:poll_ansible_tower_job_status, 20, kind_of(Hash))
        subject.poll_ansible_tower_job_status(10)
      end
    end

    context 'tower job finishes normally' do
      let(:ansible_job) { double(:raw_status => double(:completed? => true, :succeeded? => true), :refresh_ems => nil) }
      before { allow(subject).to receive(:ansible_job).and_return(ansible_job) }

      context 'always log output' do
        let(:options) { {:tower_job_id => 'jb1', :log_output => 'always'} }

        it 'gets ansible output and moves on to post_ansible_run with ok status' do
          expect(ansible_job).to receive(:raw_stdout)
          expect(subject).to receive(:signal).with(:post_ansible_run, kind_of(String), 'ok')
          subject.poll_ansible_tower_job_status(10)
        end
      end

      context 'log output on error' do
        let(:options) { {:tower_job_id => 'jb1', :log_output => 'on_error'} }

        it 'moves on to post_ansible_run with ok status' do
          expect(ansible_job).not_to receive(:raw_stdout)
          expect(subject).to receive(:signal).with(:post_ansible_run, kind_of(String), 'ok')
          subject.poll_ansible_tower_job_status(10)
        end
      end
    end

    context 'tower job fails' do
      let(:ansible_job) { double(:raw_status => double(:completed? => true, :succeeded? => false), :refresh_ems => nil) }
      before { allow(subject).to receive(:ansible_job).and_return(ansible_job) }

      context 'log output on error' do
        let(:options) { {:tower_job_id => 'jb1', :log_output => 'on_error'} }

        it 'gets ansible outputs and moves on to post_ansible_run with error status' do
          expect(ansible_job).to receive(:raw_stdout)
          expect(subject).to receive(:signal).with(:post_ansible_run, kind_of(String), 'error')
          subject.poll_ansible_tower_job_status(10)
        end
      end

      context 'never log output' do
        let(:options) { {:tower_job_id => 'jb1', :log_output => 'never'} }

        it 'moves on to post_ansible_run with error status' do
          expect(ansible_job).not_to receive(:raw_stdout)
          expect(subject).to receive(:signal).with(:post_ansible_run, kind_of(String), 'error')
          subject.poll_ansible_tower_job_status(10)
        end
      end
    end

    context 'error is raised' do
      before { allow(subject).to receive(:ansible_job).and_raise('internal error') }

      it 'moves on to post_ansible_run with error message' do
        expect(subject).to receive(:signal).with(:post_ansible_run, 'internal error', 'error')
        subject.poll_ansible_tower_job_status(10)
      end
    end
  end

  describe '#post_ansible_run' do
    let(:options) { {:job_template_ref => 'jt1'} }

    context 'playbook runs successfully' do
      it 'removes temporary job template and finishes the job' do
        expect(subject).to receive(:save_playbook_set_stats)
        expect(subject).to receive(:delete_job_template)
        subject.post_ansible_run('Playbook ran successfully', 'ok')
        expect(subject).to have_attributes(:state => 'finished', :status => 'ok')
      end
    end

    context 'playbook runs with error' do
      it 'removes temporary job template and finishes the job with error' do
        expect(subject).to receive(:save_playbook_set_stats)
        expect(subject).to receive(:delete_job_template)
        subject.post_ansible_run('Ansible engine returned an error for the job', 'error')
        expect(subject).to have_attributes(:state => 'finished', :status => 'error')
      end
    end

    context 'cleaning up has error' do
      it 'does fail the job but logs the error' do
        expect(subject).to receive(:save_playbook_set_stats)
        allow(subject).to receive(:temp_configuration_script).and_raise('fake error')
        expect($log).to receive(:log_backtrace)
        subject.post_ansible_run('Playbook ran successfully', 'ok')
        expect(subject).to have_attributes(
          :state   => 'finished',
          :status  => 'ok',
          :message => 'Playbook ran successfully; Cleanup encountered error'
        )
      end
    end
  end

  describe 'state transitions' do
    let(:options) { {} }

    %w[start create_job_template launch_ansible_tower_job poll_ansible_tower_job_status post_ansible_run finish abort_job cancel error].each do |signal|
      shared_examples_for "allows #{signal} signal" do
        it signal.to_s do
          expect(subject).to receive(signal.to_sym)
          subject.signal(signal.to_sym)
        end
      end
    end

    %w[start create_job_template launch_ansible_tower_job poll_ansible_tower_job_status post_ansible_run].each do |signal|
      shared_examples_for "does not allow #{signal} signal" do
        it signal.to_s do
          expect { subject.signal(signal.to_sym) }.to raise_error(RuntimeError, /#{signal} is not permitted at state #{subject.state}/)
        end
      end
    end

    context 'in waiting_to_start state' do
      before { subject.state = 'waiting_to_start' }

      it_behaves_like 'allows start signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'does not allow create_job_template signal'
      it_behaves_like 'does not allow launch_ansible_tower_job signal'
      it_behaves_like 'does not allow poll_ansible_tower_job_status signal'
      it_behaves_like 'does not allow post_ansible_run signal'
    end

    context 'in running state' do
      before { subject.state = 'running' }

      it_behaves_like 'allows create_job_template signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'does not allow start signal'
      it_behaves_like 'does not allow launch_ansible_tower_job signal'
      it_behaves_like 'does not allow poll_ansible_tower_job_status signal'
      it_behaves_like 'does not allow post_ansible_run signal'
    end

    context 'in job_template state' do
      before { subject.state = 'job_template' }

      it_behaves_like 'allows launch_ansible_tower_job signal'
      it_behaves_like 'allows post_ansible_run signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'does not allow start signal'
      it_behaves_like 'does not allow create_job_template signal'
      it_behaves_like 'does not allow poll_ansible_tower_job_status signal'
    end

    context 'in ansible_job state' do
      before { subject.state = 'ansible_job' }

      it_behaves_like 'allows poll_ansible_tower_job_status signal'
      it_behaves_like 'allows post_ansible_run signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'does not allow start signal'
      it_behaves_like 'does not allow create_job_template signal'
      it_behaves_like 'does not allow launch_ansible_tower_job signal'
    end

    context 'in ansible_done state' do
      before { subject.state = 'ansible_done' }
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'does not allow start signal'
      it_behaves_like 'does not allow launch_ansible_tower_job signal'
      it_behaves_like 'does not allow poll_ansible_tower_job_status signal'
      it_behaves_like 'does not allow post_ansible_run signal'
    end
  end
end
