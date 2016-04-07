describe ManageIQ::Providers::Vmware::InfraManager::Vm::RemoteConsole do
  let(:user) { FactoryGirl.create(:user) }
  let(:ems) do
    FactoryGirl.create(:ems_vmware,
                       :hostname    => '192.168.252.16',
                       :ipaddress   => '192.168.252.16',
                       :api_version => '5.0',
                       :uid_ems     => '2E1C1E82-BD83-4E54-9271-630C6DFAD4D1')
  end
  let(:vm) { FactoryGirl.create(:vm_with_ref, :ext_management_system => ems) }

  context '#remote_console_acquire_ticket' do
    it 'with :mks' do
      expect(vm).to receive(:remote_console_mks_acquire_ticket).with(user.userid)
      vm.remote_console_acquire_ticket(user.userid, :mks)
    end

    it 'with :vmrc' do
      expect(vm).to receive(:remote_console_vmrc_acquire_ticket).with(user.userid)
      vm.remote_console_acquire_ticket(user.userid, :vmrc)
    end

    it 'with :vnc' do
      expect(vm).to receive(:remote_console_vnc_acquire_ticket).with(user.userid)
      vm.remote_console_acquire_ticket(user.userid, :vnc)
    end
  end

  context '#remote_console_acquire_ticket_queue' do
    let(:server) { double('MiqServer') }

    before(:each) do
      allow(vm).to receive_messages(:my_zone => nil)
      allow(server).to receive_messages(:my_zone => nil)
      allow(MiqServer).to receive_messages(:my_server => server)
    end

    it 'with :mks' do
      vm.remote_console_acquire_ticket_queue(:mks, user.userid)

      q_all = MiqQueue.all
      expect(q_all.length).to eq(1)
      expect(q_all[0].method_name).to eq('remote_console_acquire_ticket')
      expect(q_all[0].args).to eq([user.userid, :mks])
    end

    it 'with :vmrc' do
      vm.remote_console_acquire_ticket_queue(:vmrc, user.userid)

      q_all = MiqQueue.all
      expect(q_all.length).to eq(1)
      expect(q_all[0].method_name).to eq('remote_console_acquire_ticket')
      expect(q_all[0].args).to eq([user.userid, :vmrc])
    end

    it 'with :vnc' do
      vm.remote_console_acquire_ticket_queue(:vnc, user.userid)

      q_all = MiqQueue.all
      expect(q_all.length).to eq(1)
      expect(q_all[0].method_name).to eq('remote_console_acquire_ticket')
      expect(q_all[0].args).to eq([user.userid, :vnc])
    end
  end

  context '#remote_console_vmrc_acquire_ticket' do
    it 'normal case' do
      EvmSpecHelper.create_guid_miq_server_zone
      ems.update_attributes(:ipaddress => '192.168.252.14', :hostname => '192.168.252.14')
      auth = FactoryGirl.create(:authentication,
                                :userid   => 'dev1',
                                :password => 'dev1pass',
                                :authtype => 'default')
      ems.authentications = [auth]
      ticket = VCR.use_cassette(described_class.name.underscore) do
        vm.remote_console_vmrc_acquire_ticket
      end
      expect(ticket).to match(/^[0-9\-A-Z]{40}$/)
    end

    it 'with vm off' do
      vm.update_attribute(:raw_power_state, 'poweredOff')
      expect { vm.remote_console_vmrc_acquire_ticket }.to raise_error MiqException::RemoteConsoleNotSupportedError
    end

    it 'with vm with no ems' do
      vm.ext_management_system = nil
      vm.save!
      expect { vm.remote_console_vmrc_acquire_ticket }.to raise_error MiqException::RemoteConsoleNotSupportedError
    end
  end

  context '#validate_remote_console_vmrc_support' do
    it 'normal case' do
      expect(vm.validate_remote_console_vmrc_support).to be_truthy
    end

    it 'with vm with no ems' do
      vm.ext_management_system = nil
      vm.save!
      expect { vm.validate_remote_console_vmrc_support }.to raise_error MiqException::RemoteConsoleNotSupportedError
    end

    it 'with vm off' do
      vm.update_attribute(:raw_power_state, 'poweredOff')
      expect { vm.validate_remote_console_vmrc_support }.to raise_error MiqException::RemoteConsoleNotSupportedError
    end

    it 'on VC 4.0' do
      ems.update_attribute(:api_version, '4.0')
      expect { vm.validate_remote_console_vmrc_support }.to raise_error MiqException::RemoteConsoleNotSupportedError
    end
  end

  context '#remote_console_vnc_acquire_ticket' do
    let(:ems) { FactoryGirl.create(:ems_vmware) }
    let(:host) do
      FactoryGirl.create(:host_vmware,
                         :ext_management_system   => ems,
                         :hostname                => '192.168.252.4',
                         :ipaddress               => '192.168.252.4',
                         :next_available_vnc_port => 5901)
    end
    let(:vm) { FactoryGirl.create(:vm_with_ref, :ext_management_system => ems, :host => host) }

    it 'will set the attributes on the VC side' do
      vim_vm = double('MiqVimVm')
      expect(vim_vm).to receive(:setRemoteDisplayVncAttributes) do |args|
        expect(args[:enabled]).to be_truthy
        expect(args[:port]).to eq(5901)
        expect(args[:password]).to match(%r{^[A-Za-z0-9+/]{8}$})
      end
      allow(vm).to receive(:with_provider_object).and_yield(vim_vm)

      vm.remote_console_vnc_acquire_ticket(user.userid)
    end

    it 'will set the attributes on the requester side' do
      expect(vm).to receive(:with_provider_object)

      config = vm.remote_console_vnc_acquire_ticket(user.userid)

      expect(config[:secret]).to match(%r{^[A-Za-z0-9+/]{8}$})
      expect(config[:url]).to match(%r{^ws/console/[0-9a-f]{32}/?$})
      expect(config[:proto]).to eq('vnc')
    end

    it 'will save the ticket to the database' do
      expect(vm).to receive(:with_provider_object)

      config = vm.remote_console_vnc_acquire_ticket(user.userid)
      match = config[:url].match(%r{^ws/console/([0-9a-f]{32})/?$})
      expect(match).not_to be_nil

      record = SystemConsole.find_by(:url_secret => match[1])
      expect(record.host_name).to eq('192.168.252.4')
      expect(record.port).to eq(5901)
      expect(record.protocol).to eq('vnc')
    end

    it 'will reclaim the port number from old VMs' do
      allow_any_instance_of(ManageIQ::Providers::Vmware::InfraManager::Vm).to receive(:with_provider_object)
      vm_old = FactoryGirl.create(:vm_with_ref, :host => host, :vnc_port => 5901)

      vm.remote_console_vnc_acquire_ticket(user.userid)

      vm_old.reload
      expect(vm_old.vnc_port).to be_nil
    end
  end
end
