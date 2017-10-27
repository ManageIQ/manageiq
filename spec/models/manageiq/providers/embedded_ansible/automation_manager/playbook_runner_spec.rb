describe ManageIQ::Providers::EmbeddedAnsible::AutomationManager::PlaybookRunner do
  let(:manager)  { FactoryGirl.create(:embedded_automation_manager_ansible) }
  let(:playbook) { FactoryGirl.create(:embedded_playbook, :manager => manager) }
  subject { ManageIQ::Providers::EmbeddedAnsible::AutomationManager::PlaybookRunner.create_job(options.merge(:playbook_id => playbook.id)) }

  describe '#start' do
    context 'inventory is given' do
      let(:options) { {:inventory => '3'} }

      it 'moves on to create_job_template' do
        expect(subject).to receive(:queue_signal).with(:create_job_template, :deliver_on => nil)
        subject.start
      end
    end

    context 'hosts are given' do
      let(:options) { {:hosts => 'host1,localhost'} }

      it 'moves on to create inventory' do
        expect(subject).to receive(:queue_signal).with(:create_inventory, :deliver_on => nil)
        subject.start
      end
    end
  end

  describe '#create_inventory' do
    context 'localhost is used' do
      let(:options) { {:hosts => 'localhost'} }

      it 'uses default inventory and moves on to create_job_template' do
        subject.send(:minimize_indirect=, false)
        allow(subject).to receive(:playbook).and_return(double(:manager => double(:provider => double(:default_inventory => 'default'))))
        expect(subject).to receive(:queue_signal).with(:create_job_template, :deliver_on => nil)
        subject.create_inventory
        expect(subject.options).to have_attributes(:inventory => 'default')
      end
    end

    context 'other hosts are used' do
      # Use string key to also test the indifferent accessibility
      let(:options) { {'hosts' => 'host1,host2'} }

      it 'creates an inventory and moves on to create_job_template' do
        expect(ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Inventory).to receive(:raw_create_inventory).and_return(double(:id => 'inv1'))
        expect(subject).to receive(:signal).with(:create_job_template)
        subject.create_inventory
        expect(subject.options[:inventory]).to eq('inv1')
      end
    end

    context 'error is raised' do
      let(:options) { {:hosts => 'host1,host2'} }

      it 'moves on to post_ansible_run' do
        allow(ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Inventory).to receive(:raw_create_inventory).and_raise("can't complete the request")
        expect(subject).to receive(:signal).with(:post_ansible_run, "can't complete the request", "error")
        subject.create_inventory
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
        expect(subject.options).to have_attributes(:job_template_ref => 'jt_ref')
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
        expect(ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Job).to receive(:create_job).and_return(double(:id => 'jb1'))
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
  end

  describe '#poll_ansible_tower_job_status' do
    let(:options) { {:tower_job_id => 'jb1'} }

    context 'tower job is still running' do
      before { allow(subject).to receive(:tower_job).and_return(double(:raw_status => double(:completed? => false))) }

      it 'requeues for later poll' do
        expect(subject).to receive(:queue_signal).with(:poll_ansible_tower_job_status, 20, kind_of(Hash))
        subject.poll_ansible_tower_job_status(10)
      end
    end

    context 'tower job finishes normally' do
      before { allow(subject).to receive(:tower_job).and_return(double(:raw_status => double(:completed? => true, :succeeded? => true), :refresh_ems => nil)) }

      it 'moves on to post_ansible_run with ok status' do
        expect(subject).to receive(:signal).with(:post_ansible_run, kind_of(String), 'ok')
        subject.poll_ansible_tower_job_status(10)
      end
    end

    context 'tower job fails' do
      before { allow(subject).to receive(:tower_job).and_return(double(:raw_status => double(:completed? => true, :succeeded? => false), :refresh_ems => nil)) }

      it 'moves on to post_ansible_run with error status' do
        expect(subject).to receive(:signal).with(:post_ansible_run, kind_of(String), 'error')
        subject.poll_ansible_tower_job_status(10)
      end
    end

    context 'error is raised' do
      before { allow(subject).to receive(:tower_job).and_raise('internal error') }

      it 'moves on to post_ansible_run with error message' do
        expect(subject).to receive(:signal).with(:post_ansible_run, 'internal error', 'error')
        subject.poll_ansible_tower_job_status(10)
      end
    end
  end

  describe 'state transitions' do
    let(:options) { {} }

    %w(start create_inventory create_job_template launch_ansible_tower_job poll_ansible_tower_job_status post_ansible_run finish abort_job cancel error).each do |signal|
      shared_examples_for "allows #{signal} signal" do
        it signal.to_s do
          expect(subject).to receive(signal.to_sym)
          subject.signal(signal.to_sym)
        end
      end
    end

    %w(start create_inventory create_job_template launch_ansible_tower_job poll_ansible_tower_job_status post_ansible_run).each do |signal|
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

      it_behaves_like 'does not allow create_inventory signal'
      it_behaves_like 'does not allow create_job_template signal'
      it_behaves_like 'does not allow launch_ansible_tower_job signal'
      it_behaves_like 'does not allow poll_ansible_tower_job_status signal'
      it_behaves_like 'does not allow post_ansible_run signal'
    end

    context 'in running state' do
      before { subject.state = 'running' }

      it_behaves_like 'allows create_inventory signal'
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

    context 'in inventory state' do
      before { subject.state = 'inventory' }

      it_behaves_like 'allows create_job_template signal'
      it_behaves_like 'allows post_ansible_run signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'does not allow start signal'
      it_behaves_like 'does not allow create_inventory signal'
      it_behaves_like 'does not allow launch_ansible_tower_job signal'
      it_behaves_like 'does not allow poll_ansible_tower_job_status signal'
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
      it_behaves_like 'does not allow create_inventory signal'
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
      it_behaves_like 'does not allow create_inventory signal'
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
      it_behaves_like 'does not allow create_inventory signal'
      it_behaves_like 'does not allow launch_ansible_tower_job signal'
      it_behaves_like 'does not allow poll_ansible_tower_job_status signal'
      it_behaves_like 'does not allow post_ansible_run signal'
    end
  end
end
