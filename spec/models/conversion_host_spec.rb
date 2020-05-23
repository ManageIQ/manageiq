require 'manageiq-ssh-util'

RSpec.describe ConversionHost, :v2v do
  let(:apst) { FactoryBot.create(:service_template_ansible_playbook) }

  context "provider independent methods" do
    let(:ems) { FactoryBot.create(:ems_redhat, :zone => FactoryBot.create(:zone), :api_version => '4.2.4') }
    let(:host) { FactoryBot.create(:host_redhat, :ext_management_system => ems) }
    let(:vm) { FactoryBot.create(:vm_openstack) }
    let(:conversion_host_1) { FactoryBot.create(:conversion_host, :resource => host) }
    let(:conversion_host_2) { FactoryBot.create(:conversion_host, :resource => vm) }
    let(:task_1) { FactoryBot.create(:service_template_transformation_plan_task, :state => 'active', :conversion_host => conversion_host_1) }
    let(:task_2) { FactoryBot.create(:service_template_transformation_plan_task, :conversion_host => conversion_host_1) }
    let(:task_3) { FactoryBot.create(:service_template_transformation_plan_task, :state => 'migrate', :conversion_host => conversion_host_2) }

    before do
      allow(conversion_host_1).to receive(:active_tasks).and_return([task_1])
      allow(conversion_host_2).to receive(:active_tasks).and_return([task_3])

      allow(host).to receive(:ipaddresses).and_return(['10.0.0.1', 'FE80:0000:0000:0000:0202:B3FF:FE1E:8329', '192.168.0.1'])
      allow(host).to receive(:ipaddress).and_return(nil)
      allow(vm).to receive(:ipaddresses).and_return(['10.0.1.1', 'FE80::0202:B3FF:FE1E:3267', '192.168.1.1'])
    end

    context "#eligible?" do
      it "fails when no source transport method is enabled" do
        allow(conversion_host_1).to receive(:source_transport_method).and_return(nil)
        allow(conversion_host_1).to receive(:authentication_check).and_return([true, 'worked'])
        allow(conversion_host_1).to receive(:check_concurrent_tasks).and_return(true)
        expect(conversion_host_1.eligible?).to eq(false)
      end

      it "fails when authentication check fails" do
        allow(conversion_host_1).to receive(:source_transport_method).and_return('vddk')
        allow(conversion_host_1).to receive(:authentication_check).and_return([false, 'failed'])
        allow(conversion_host_1).to receive(:check_concurrent_tasks).and_return(true)
        expect(conversion_host_1.eligible?).to eq(false)
      end

      it "fails when concurrent tasks check fails" do
        allow(conversion_host_1).to receive(:source_transport_method).and_return('vddk')
        allow(conversion_host_1).to receive(:authentication_check).and_return([true, 'worked'])
        allow(conversion_host_1).to receive(:check_concurrent_tasks).and_return(false)
        expect(conversion_host_1.eligible?).to eq(false)
      end

      it "succeeds when all criteria are met" do
        allow(conversion_host_1).to receive(:source_transport_method).and_return('vddk')
        allow(conversion_host_1).to receive(:authentication_check).and_return([true, 'worked'])
        allow(conversion_host_1).to receive(:check_concurrent_tasks).and_return(true)
        expect(conversion_host_1.eligible?).to eq(true)
      end
    end

    context "#warm_migration_eligible?" do
      it "fails when source transport method is ssh" do
        allow(conversion_host_1).to receive(:source_transport_method).and_return('ssh')
        allow(conversion_host_1).to receive(:authentication_check).and_return([true, 'worked'])
        allow(conversion_host_1).to receive(:check_concurrent_tasks).and_return(true)
        expect(conversion_host_1.warm_migration_eligible?).to eq(false)
      end

      it "succeeds when all criteria are met" do
        allow(conversion_host_1).to receive(:source_transport_method).and_return('vddk')
        allow(conversion_host_1).to receive(:authentication_check).and_return([true, 'worked'])
        allow(conversion_host_1).to receive(:check_concurrent_tasks).and_return(true)
        expect(conversion_host_1.eligible?).to eq(true)
      end
    end

    context "#check_concurrent_tasks" do
      context "default max concurrent tasks is equal to current active tasks" do
        before { stub_settings_merge(:transformation => {:limits => {:max_concurrent_tasks_per_conversion_host => 1}}) }
        it { expect(conversion_host_1.check_concurrent_tasks).to eq(false) }
      end

      context "default max concurrent tasks is greater than current active tasks" do
        before { stub_settings_merge(:transformation => {:limits => {:max_concurrent_tasks_per_conversion_host => 10}}) }
        it { expect(conversion_host_1.check_concurrent_tasks).to eq(true) }
      end

      context "host's max concurrent tasks is equal to current active tasks" do
        before { conversion_host_1.max_concurrent_tasks = "1" }
        it { expect(conversion_host_1.check_concurrent_tasks).to eq(false) }
      end

      context "host's max concurrent tasks greater than current active tasks" do
        before { conversion_host_2.max_concurrent_tasks = "2" }
        it { expect(conversion_host_2.check_concurrent_tasks).to eq(true) }
      end
    end

    context "#source_transport_method" do
      it { expect(conversion_host_2.source_transport_method).to be_nil }

      context "ssh transport enabled" do
        before { conversion_host_2.ssh_transport_supported = true }
        it { expect(conversion_host_2.source_transport_method).to eq('ssh') }

        context "vddk transport enabled" do
          before { conversion_host_2.vddk_transport_supported = true }
          it { expect(conversion_host_2.source_transport_method).to eq('vddk') }
        end
      end
    end

    context "#ipaddress" do
      it "returns first IP address if 'address' is nil" do
        expect(conversion_host_1.ipaddress).to eq('10.0.0.1')
        expect(conversion_host_2.ipaddress).to eq('10.0.1.1')
        expect(conversion_host_1.ipaddress('ipv4')).to eq('10.0.0.1')
        expect(conversion_host_2.ipaddress('ipv4')).to eq('10.0.1.1')
        expect(conversion_host_1.ipaddress('ipv6')).to eq('FE80:0000:0000:0000:0202:B3FF:FE1E:8329')
        expect(conversion_host_2.ipaddress('ipv6')).to eq('FE80::0202:B3FF:FE1E:3267')
      end

      context "when address is set" do
        before do
          allow(conversion_host_1).to receive(:address).and_return('172.16.0.1')
          allow(conversion_host_2).to receive(:address).and_return('2001:0DB8:85A3:0000:0000:8A2E:0370:7334')
        end

        it "returns 'address' if family matches, is invalid or is nil" do
          expect(conversion_host_1.ipaddress).to eq('172.16.0.1')
          expect(conversion_host_2.ipaddress).to eq('10.0.1.1')
          expect(conversion_host_1.ipaddress('ipv4')).to eq('172.16.0.1')
          expect(conversion_host_2.ipaddress('ipv4')).to eq('10.0.1.1')
          expect(conversion_host_1.ipaddress('ipv6')).to eq('FE80:0000:0000:0000:0202:B3FF:FE1E:8329')
          expect(conversion_host_2.ipaddress('ipv6')).to eq('2001:0DB8:85A3:0000:0000:8A2E:0370:7334')
        end
      end
    end

    context "#kill_process" do
      it "returns false if if kill command failed" do
        allow(conversion_host_1).to receive(:connect_ssh).and_raise('Unexpected failure')
        expect(conversion_host_1.kill_virtv2v(task_1.id, 'TERM')).to eq(false)
      end

      it "returns true if if kill command succeeded" do
        allow(conversion_host_1).to receive(:connect_ssh)
        expect(conversion_host_1.kill_virtv2v(task_1.id, 'KILL')).to eq(true)
      end
    end
  end

  shared_examples_for "#check_ssh_connection" do
    it "fails when SSH send an error" do
      allow(conversion_host).to receive(:connect_ssh).and_raise('Unexpected failure')
      expect(conversion_host.check_ssh_connection).to eq(false)
    end

    it "succeeds when SSH command succeeds" do
      allow(conversion_host).to receive(:connect_ssh)
      expect(conversion_host.check_ssh_connection).to eq(true)
    end
  end

  context "resource provider is rhevm" do
    let(:ems) { FactoryBot.create(:ems_redhat, :zone => FactoryBot.create(:zone), :api_version => '4.2.4') }
    let(:host) { FactoryBot.create(:host_redhat, :ext_management_system => ems) }
    let(:conversion_host) { FactoryBot.create(:conversion_host, :resource => host, :vddk_transport_supported => true) }

    context "host userid is nil" do
      before { allow(host).to receive(:authentication_userid).and_return(nil) }
      it { expect(conversion_host.check_ssh_connection).to eq(false) }
    end

    context "host userid is set" do
      before { allow(host).to receive(:authentication_userid).and_return('root') }

      context "and host password is nil" do
        before { allow(host).to receive(:authentication_password).and_return(nil) }
        it { expect(conversion_host.check_ssh_connection).to eq(false) }
      end

      context "and host password is set" do
        before { allow(host).to receive(:authentication_password).and_return('password') }
        it_behaves_like "#check_ssh_connection"
      end
    end

    context "#ansible_playbook" do
      let(:auth_v2v) { FactoryBot.create(:authentication_v2v, :resource => conversion_host) }
      let(:package_url) { 'http://file.example.com/vddk-stable.tar.gz' }
      let(:enable_playbook) { '/usr/share/v2v-conversion-host-ansible/playbooks/conversion_host_enable.yml' }

      it "check_conversion_host_role doesn't call ansible_playbook if resource is absent" do
        allow(conversion_host).to receive(:resource).and_return(nil)
        expect(conversion_host).not_to receive(:ansible_playbook)
        conversion_host.check_conversion_host_role(1)
      end

      it "check_conversion_host_role doesn't call ansible_playbook if resource is archived" do
        allow(conversion_host.resource).to receive(:ext_management_system).and_return(nil)
        expect(conversion_host).not_to receive(:ansible_playbook)
        conversion_host.check_conversion_host_role(1)
      end

      it "check_conversion_host_role calls ansible_playbook with extra_vars" do
        check_playbook = '/usr/share/v2v-conversion-host-ansible/playbooks/conversion_host_check.yml'
        check_extra_vars = {
          :v2v_host_type        => 'rhevm',
          :v2v_transport_method => 'vddk'
        }
        expect(conversion_host).to receive(:ansible_playbook).with(check_playbook, check_extra_vars, 1)
        conversion_host.check_conversion_host_role(1)
      end

      it "disable_conversion_host_role doesn't call ansible_playbook if resource is absent" do
        allow(conversion_host).to receive(:resource).and_return(nil)
        expect(conversion_host).not_to receive(:ansible_playbook)
        conversion_host.disable_conversion_host_role(1)
      end

      it "disable_conversion_host_role doesn't call ansible_playbook if resource is archived" do
        allow(conversion_host.resource).to receive(:ext_management_system).and_return(nil)
        expect(conversion_host).not_to receive(:ansible_playbook)
        conversion_host.disable_conversion_host_role(1)
      end

      it "disable_conversion_host_role calls ansible_playbook with extra_vars" do
        disable_playbook = '/usr/share/v2v-conversion-host-ansible/playbooks/conversion_host_disable.yml'
        check_playbook = '/usr/share/v2v-conversion-host-ansible/playbooks/conversion_host_check.yml'
        disable_extra_vars = {
          :v2v_host_type        => 'rhevm',
          :v2v_transport_method => 'vddk'
        }
        check_extra_vars = disable_extra_vars
        expect(conversion_host).to receive(:ansible_playbook).once.ordered.with(disable_playbook, disable_extra_vars, 1)
        expect(conversion_host).to receive(:ansible_playbook).once.ordered.with(check_playbook, check_extra_vars, 1)
        conversion_host.disable_conversion_host_role(1)
      end

      it "enable_conversion_host_role doesn't call ansible_playbook if resource is absent" do
        allow(conversion_host).to receive(:resource).and_return(nil)
        expect(conversion_host).not_to receive(:ansible_playbook)
        conversion_host.enable_conversion_host_role(1)
      end

      it "enable_conversion_host_role doesn't call ansible_playbook if resource is archived" do
        allow(conversion_host.resource).to receive(:ext_management_system).and_return(nil)
        expect(conversion_host).not_to receive(:ansible_playbook)
        conversion_host.enable_conversion_host_role(1)
      end

      it "enable_conversion_host_role raises if vmware_vddk_package_url is nil" do
        expect { conversion_host.enable_conversion_host_role }.to raise_error("vmware_vddk_package_url is mandatory if transformation method is vddk")
      end

      it "enable_conversion_host_role raises if resource has no hostname nor IP address" do
        allow(host).to receive(:hostname).and_return(nil)
        allow(host).to receive(:ipaddresses).and_return([])
        expect { conversion_host.enable_conversion_host_role('http://file.example.com/vddk-stable.tar.gz', nil) }.to raise_error("Host '#{host.name}' doesn't have a hostname or IP address in inventory")
      end

      it "enable_conversion_host_role calls ansible_playbook with extra_vars" do
        check_playbook = '/usr/share/v2v-conversion-host-ansible/playbooks/conversion_host_check.yml'
        enable_extra_vars = {
          :v2v_host_type        => 'rhevm',
          :v2v_transport_method => 'vddk',
          :v2v_vddk_package_url => package_url
        }
        check_extra_vars = {
          :v2v_host_type        => 'rhevm',
          :v2v_transport_method => 'vddk'
        }
        expect(conversion_host).to receive(:ansible_playbook).once.ordered.with(enable_playbook, enable_extra_vars, nil)
        expect(conversion_host).to receive(:ansible_playbook).once.ordered.with(check_playbook, check_extra_vars, nil)
        conversion_host.enable_conversion_host_role('http://file.example.com/vddk-stable.tar.gz', nil)
      end

      it "logs an error message if the ansible_playbook command fails" do
        command = "ansible_playbook #{enable_playbook}"
        result = instance_double(AwesomeSpawn::CommandResult, :command_line => command, :failure? => true, :error => "oops")

        allow(conversion_host).to receive(:check_conversion_host_role)
        allow(conversion_host).to receive(:find_credentials).and_return(auth_v2v)
        allow(AwesomeSpawn).to receive(:run).and_return(result)

        expect($log).to receive(:error).with("MIQ(ConversionHost#ansible_playbook) #{command} ==> oops")
        expect { conversion_host.enable_conversion_host_role(package_url, nil) }.to raise_error(RuntimeError)
      end
    end
  end

  context "resource provider is openstack" do
    let(:ems) { FactoryBot.create(:ems_openstack, :zone => FactoryBot.create(:zone)) }
    let(:vm) { FactoryBot.create(:vm_openstack, :ext_management_system => ems) }
    let(:conversion_host) { FactoryBot.create(:conversion_host, :resource => vm, :ssh_transport_supported => true) }

    context "ems authentications is empty" do
      it { expect(conversion_host.check_ssh_connection).to be(false) }
    end

    context "ems authentications contains ssh_auth" do
      let(:ssh_auth) { FactoryBot.create(:authentication_ssh_keypair, :resource => ems) }

      before do
        allow(ems).to receive(:authentications).and_return(ssh_auth)
      end

      it_behaves_like "#check_ssh_connection"
    end

    context "#ansible_playbook" do
      it "check_conversion_host_role calls ansible_playbook with extra_vars" do
        check_playbook = '/usr/share/v2v-conversion-host-ansible/playbooks/conversion_host_check.yml'
        check_extra_vars = {
          :v2v_host_type        => 'openstack',
          :v2v_transport_method => 'ssh'
        }
        expect(conversion_host).to receive(:ansible_playbook).with(check_playbook, check_extra_vars, 1)
        conversion_host.check_conversion_host_role(1)
      end

      it "disable_conversion_host_role calls ansible_playbook with extra_vars" do
        disable_playbook = '/usr/share/v2v-conversion-host-ansible/playbooks/conversion_host_disable.yml'
        check_playbook = '/usr/share/v2v-conversion-host-ansible/playbooks/conversion_host_check.yml'
        disable_extra_vars = {
          :v2v_host_type        => 'openstack',
          :v2v_transport_method => 'ssh'
        }
        check_extra_vars = disable_extra_vars
        expect(conversion_host).to receive(:ansible_playbook).once.ordered.with(disable_playbook, disable_extra_vars, 1)
        expect(conversion_host).to receive(:ansible_playbook).once.ordered.with(check_playbook, check_extra_vars, 1)
        conversion_host.disable_conversion_host_role(1)
      end

      it "enable_conversion_host_role raises if vmware_ssh_private_key is nil" do
        expect { conversion_host.enable_conversion_host_role }.to raise_error("vmware_ssh_private_key is mandatory if transformation_method is ssh")
      end

      it "enable_conversion_host_role calls ansible_playbook with extra_vars" do
        enable_playbook = '/usr/share/v2v-conversion-host-ansible/playbooks/conversion_host_enable.yml'
        check_playbook = '/usr/share/v2v-conversion-host-ansible/playbooks/conversion_host_check.yml'
        enable_extra_vars = {
          :v2v_host_type        => 'openstack',
          :v2v_transport_method => 'ssh',
          :v2v_ssh_private_key  => 'fake ssh private key',
          :v2v_ca_bundle        => 'fake CA bundle'
        }
        check_extra_vars = {
          :v2v_host_type        => 'openstack',
          :v2v_transport_method => 'ssh'
        }
        expect(conversion_host).to receive(:ansible_playbook).once.ordered.with(enable_playbook, enable_extra_vars, nil)
        expect(conversion_host).to receive(:ansible_playbook).once.ordered.with(check_playbook, check_extra_vars, nil)
        conversion_host.enable_conversion_host_role(nil, 'fake ssh private key', 'fake CA bundle')
      end
    end
  end

  context "address validation" do
    let(:vm) { FactoryBot.create(:vm_openstack) }

    it "is invalid if the address is not a valid IP address" do
      allow(vm).to receive(:ipaddresses).and_return(['127.0.0.1'])
      conversion_host = ConversionHost.new(:name => "test", :resource => vm, :address => "xxx")
      expect(conversion_host.valid?).to be(false)
      expect(conversion_host.errors[:address]).to include("is invalid")
    end

    it "is invalid if the address is present but not included in the resource addresses" do
      allow(vm).to receive(:ipaddresses).and_return(['127.0.0.1'])
      conversion_host = ConversionHost.new(:name => "test", :resource => vm, :address => "127.0.0.2")
      expect(conversion_host.valid?).to be(false)
      expect(conversion_host.errors[:address]).to include("is not included in the list")
    end

    it "is valid if the address is included within the list of available resource addresses" do
      allow(vm).to receive(:ipaddresses).and_return(['127.0.0.1'])
      conversion_host = ConversionHost.new(:name => "test", :resource => vm, :address => "127.0.0.1")
      expect(conversion_host.valid?).to be(true)
    end

    it "is ignored if the resource does not have any ipaddresses" do
      conversion_host = ConversionHost.new(:name => "test", :resource => vm, :address => "127.0.0.2")
      expect(conversion_host.valid?).to be(true)
    end

    it "is valid if an address is not provided" do
      allow(vm).to receive(:ipaddresses).and_return(['127.0.0.1'])
      conversion_host = ConversionHost.new(:name => "test", :resource => vm)
      expect(conversion_host.valid?).to be(true)
    end
  end

  context "resource validation" do
    let(:ems) { FactoryBot.create(:ems_redhat, :zone => FactoryBot.create(:zone), :api_version => '4.2.4') }
    let(:redhat_host) { FactoryBot.create(:host_redhat, :ext_management_system => ems) }
    let(:azure_vm) { FactoryBot.create(:vm_azure) }

    it "is valid if the associated resource supports conversion hosts" do
      conversion_host = ConversionHost.new(:name => "test", :resource => redhat_host)
      expect(conversion_host.valid?).to be(true)
    end

    it "is invalid if the associated resource does not support conversion hosts" do
      conversion_host = ConversionHost.new(:name => "test", :resource => azure_vm)
      expect(conversion_host.valid?).to be(false)
      expect(conversion_host.errors.messages[:resource].first).to eql("Feature not available/supported")
    end

    it "is invalid if there is no associated resource" do
      conversion_host = ConversionHost.new(:name => "test2")
      expect(conversion_host.valid?).to be(false)
      expect(conversion_host.errors[:resource].first).to eql("can't be blank")
    end

    it "is invalid if the resource is already a conversion host" do
      FactoryBot.create(:conversion_host, :resource => redhat_host)
      conversion_host = ConversionHost.new(:resource => redhat_host)
      expect(conversion_host.valid?).to be(false)
      expect(conversion_host.errors[:resource_id].first).to eql("has already been taken")
    end
  end

  context "name validation" do
    let(:ems) { FactoryBot.create(:ems_redhat, :zone => FactoryBot.create(:zone), :api_version => '4.2.4') }
    let(:redhat_host) { FactoryBot.create(:host_redhat, :name => 'foo', :ext_management_system => ems) }

    it "defaults to the associated resource name if no name is explicitly provided" do
      conversion_host = ConversionHost.new(:resource => redhat_host)
      expect(conversion_host.valid?).to be(true)
      expect(conversion_host.name).to eql(redhat_host.name)
    end
  end

  context "authentication associations" do
    let(:vm) { FactoryBot.create(:vm_openstack) }
    let(:ems) { FactoryBot.create(:ems_redhat, :zone => FactoryBot.create(:zone), :api_version => '4.2.4') }
    let(:host) { FactoryBot.create(:host_redhat, :ext_management_system => ems) }

    let(:conversion_host_vm) { FactoryBot.create(:conversion_host, :resource => vm) }
    let(:conversion_host_host) { FactoryBot.create(:conversion_host, :resource => host) }

    let(:auth_keypair) { FactoryBot.create(:authentication_ssh_keypair, :resource => conversion_host_vm) }
    let(:auth_v2v) { FactoryBot.create(:authentication_v2v, :resource => conversion_host_host) }

    it "finds associated ssh_keypair authentications" do
      expect(conversion_host_vm.authentications).to contain_exactly(auth_keypair)
    end

    it "finds associated v2v authentications" do
      expect(conversion_host_host.authentications).to contain_exactly(auth_v2v)
    end

    it "allows a resource to add an authentication" do
      auth_keypair2 = FactoryBot.create(:authentication_ssh_keypair)
      conversion_host_vm.authentications << auth_keypair2
      expect(conversion_host_vm.authentications).to contain_exactly(auth_keypair, auth_keypair2)
    end
  end

  context "find_credentials" do
    let(:auth_v2v) { FactoryBot.create(:authentication_v2v, :resource => conversion_host_vm) }
    let(:ems_redhat) { FactoryBot.create(:ems_redhat, :zone => FactoryBot.create(:zone), :api_version => '4.2.4') }
    let(:ems_openstack) { FactoryBot.create(:ems_openstack, :zone => FactoryBot.create(:zone)) }
    let(:auth_default) { FactoryBot.create(:authentication) }

    let(:host) { FactoryBot.create(:host_redhat, :ext_management_system => ems_redhat) }
    let(:vm) { FactoryBot.create(:vm_openstack, :ext_management_system => ems_openstack) }

    let(:conversion_host_vm) { FactoryBot.create(:conversion_host, :resource => vm) }
    let(:conversion_host_host) { FactoryBot.create(:conversion_host, :resource => host) }

    it "finds the v2v credentials as expected when associated directly with the conversion host" do
      conversion_host_vm.authentications << auth_v2v
      expect(conversion_host_vm.send(:find_credentials)).to eq(auth_v2v)
    end

    it "finds the credentials associated with the resource if credentials cannot be found for the conversion host" do
      vm.authentications << auth_default
      host.authentications << auth_default
      expect(conversion_host_vm.send(:find_credentials)).to eq(auth_default)
      expect(conversion_host_host.send(:find_credentials)).to eq(auth_default)
    end
  end

  context "verify credentials" do
    let(:vm) { FactoryBot.create(:vm_openstack) }
    let(:conversion_host_vm) { FactoryBot.create(:conversion_host, :resource => vm) }

    it "works with no associated authentications" do
      allow(conversion_host_vm).to receive(:connect_ssh).and_return(true)
      expect(conversion_host_vm.verify_credentials).to be_truthy
    end

    it "works as expected with no associated authentications if the connect_ssh method fails" do
      allow(conversion_host_vm).to receive(:connect_ssh).and_raise(Exception.new)
      expect { conversion_host_vm.verify_credentials }.to raise_error(RuntimeError)
    end

    it "works if there is an associated validation" do
      authentication = FactoryBot.create(:authentication_ssh_keypair)
      conversion_host_vm.authentications << authentication
      allow(Net::SSH).to receive(:start).and_return(true)
      expect(conversion_host_vm.verify_credentials).to be_truthy
    end

    it "makes an ssh call if the authentication is not valid" do
      authentication = FactoryBot.create(:authentication_ssh_keypair, :status => 'Error', :authtype => 'v2v')
      conversion_host_vm.authentications << authentication
      expect(Net::SSH).to receive(:start)
      conversion_host_vm.verify_credentials
    end

    it "does not make an ssh call if the authentication is valid" do
      authentication = FactoryBot.create(:authentication_ssh_keypair, :status => 'Valid', :authtype => 'v2v')
      conversion_host_vm.authentications << authentication
      expect(Net::SSH).not_to receive(:start)
      conversion_host_vm.verify_credentials
    end

    it "makes an ssh call if the authentication status is not set" do
      authentication = FactoryBot.create(:authentication_ssh_keypair, :status => nil, :authtype => 'v2v')
      conversion_host_vm.authentications << authentication
      expect(Net::SSH).to receive(:start)
      conversion_host_vm.verify_credentials
    end

    it "works as expected if there is an associated validation that is invalid" do
      authentication = FactoryBot.create(:authentication_ssh_keypair)
      conversion_host_vm.authentications << authentication
      allow(Net::SSH).to receive(:start).and_raise(Net::SSH::AuthenticationFailed.new)
      expect { conversion_host_vm.verify_credentials }.to raise_error(Net::SSH::AuthenticationFailed, /Incorrect credentials/)
    end

    it "works if there are multiple associated validations" do
      authentications = [FactoryBot.create(:authentication_ssh_keypair)] * 2
      conversion_host_vm.authentications << authentications
      allow(Net::SSH).to receive(:start).and_return(true)
      expect(conversion_host_vm.verify_credentials).to be_truthy
    end

    it "works if an auth_type is explicitly specified" do
      authentication = FactoryBot.create(:authentication_ssh_keypair)
      conversion_host_vm.authentications << authentication
      allow(Net::SSH).to receive(:start).and_return(true)
      expect(conversion_host_vm.verify_credentials('v2v')).to be_truthy
    end
  end

  context "#run_conversion" do
    let(:vm) { FactoryBot.create(:vm_openstack) }
    let(:conversion_host) { FactoryBot.create(:conversion_host, :resource => vm) }
    let(:conversion_options) { {:foo => 1, :bar => 'hello', :password => 'xxx', :ssh_key => 'xyz' } }
    let(:filtered_options) { conversion_options.clone.update(:ssh_key => '__FILTERED__', :password => '__FILTERED__') }

    it "works as expected if the connection is unsuccessful" do
      allow(conversion_host).to receive(:connect_ssh).and_raise(Net::SSH::AuthenticationFailed)
      expected_message = "Failed to connect and run conversion using options #{filtered_options}"
      expect { conversion_host.run_conversion(conversion_options) }.to raise_error(/#{expected_message}/)
    end

    it "works as expected if an unknown error occurs" do
      allow(conversion_host).to receive(:connect_ssh).and_raise(StandardError, 'fake error')
      expected_message = "Starting conversion failed on '#{vm.name}' with [StandardError: fake error]"
      expect { conversion_host.run_conversion(conversion_options) }.to raise_error(expected_message)
    end

    it "works as expected if the connection is successful and the JSON is valid" do
      allow(conversion_host).to receive(:connect_ssh).and_return({:alpha => {:beta => 'hello'}}.to_json)
      expect(conversion_host.run_conversion(conversion_options)).to eql('alpha' => {'beta' => 'hello'})
    end

    it "works as expected if the connection is successful but the JSON is invalid" do
      allow(conversion_host).to receive(:connect_ssh).and_return('bogus')
      expected_message = "Could not parse result data after running virt-v2v-wrapper using options: #{filtered_options}. Result was: bogus"
      expect { conversion_host.run_conversion(conversion_options) }.to raise_error(expected_message)
    end
  end

  context "#get_conversion_state" do
    let(:vm) { FactoryBot.create(:vm_openstack) }
    let(:conversion_host) { FactoryBot.create(:conversion_host, :resource => vm) }
    let(:task) { FactoryBot.create(:service_template_transformation_plan_task, :conversion_host => conversion_host) }

    it "works as expected if the connection is successful and the JSON is valid" do
      allow(conversion_host).to receive(:connect_ssh).and_return({:alpha => {:beta => 'hello'}}.to_json)
      expect(conversion_host.get_conversion_state('/tmp/state.json')).to eql('alpha' => {'beta' => 'hello'})
    end

    it "works as expected if the connection is successful but the JSON is invalid" do
      allow(conversion_host).to receive(:connect_ssh).and_return('bogus')
      expected_message = "Could not parse conversion state data from file '/tmp/state.json': bogus"
      expect { conversion_host.get_conversion_state('/tmp/state.json') }.to raise_error(expected_message)
    end

    it "works as expected if the connection is unsuccessful" do
      allow(conversion_host).to receive(:connect_ssh).and_raise(Net::SSH::AuthenticationFailed)
      expected_message = "Failed to connect and retrieve conversion state data from file '\/tmp\/state.json'"
      expect { conversion_host.get_conversion_state('/tmp/state.json') }.to raise_error(/#{expected_message}/)
    end

    it "works as expected if an unknown error occurs" do
      allow(conversion_host).to receive(:connect_ssh).and_raise(StandardError)
      expected_message = "Error retrieving and parsing conversion state file '\/tmp\/state.json' from '#{vm.name}'"
      expect { conversion_host.get_conversion_state('/tmp/state.json') }.to raise_error(/#{expected_message}/)
    end
  end

  context "#apply_task_limits" do
    let(:vm) { FactoryBot.create(:vm_openstack) }
    let(:conversion_host) { FactoryBot.create(:conversion_host, :resource => vm) }
    let(:task) { FactoryBot.create(:service_template_transformation_plan_task, :conversion_host => conversion_host) }
    let(:limits) { { :cpu => '50', :network => '10' } }

    it "works as expected if the connection is successful and the JSON is generated" do
      allow(conversion_host).to receive(:connect_ssh).and_return(true)
      expect(conversion_host.apply_task_limits('/tmp/throttling.json', limits)).to be_truthy
    end

    it "works as expected if the connection is successful but the JSON is invalid" do
      allow(conversion_host).to receive(:connect_ssh).and_raise(JSON::GeneratorError, 'fake unparser error')
      expected_message = "Could not generate JSON from limits '#{limits}' with [JSON::GeneratorError: fake unparser error]"
      expect { conversion_host.apply_task_limits('/tmp/throttling.json', limits) }.to raise_error(expected_message)
    end

    it "works as expected if the connection is unsuccessful" do
      allow(conversion_host).to receive(:connect_ssh).and_raise(Net::SSH::AuthenticationFailed)
      expected_message = "Failed to connect and apply limits in file '/tmp/throttling.json'"
      expect { conversion_host.apply_task_limits('/tmp/throttling.json', limits) }.to raise_error(/#{expected_message}/)
    end

    it "works as expected if an unknown error occurs" do
      allow(conversion_host).to receive(:connect_ssh).and_raise(StandardError, 'fake error')
      expected_message = "Could not apply the limits in file '/tmp/throttling.json' on '#{vm.name}' with [StandardError: fake error]"
      expect { conversion_host.apply_task_limits('/tmp/throttling.json', limits) }.to raise_error(expected_message)
    end
  end

  context ".queue_configuration" do
    let(:params) { {:name => 'updated_config'} }
    let(:ems) { FactoryBot.create(:ems_openstack) }
    let(:vm) { FactoryBot.create(:vm_openstack, :ext_management_system => ems) }

    it "queues a configuration with the queue_configuration method" do
      task_id = described_class.queue_configuration('enable', nil, vm, params, nil)

      expect(MiqTask.find(task_id)).to have_attributes(
        :name   => "Configuring a conversion_host: operation=enable resource=(name: #{vm.name} type: #{vm.class.name} id: #{vm.id})",
        :state  => "Queued",
        :status => "Ok"
      )

      expect(MiqQueue.where(:class_name => described_class.name).first).to have_attributes(
        :class_name  => described_class.name,
        :method_name => 'enable',
        :role        => 'ems_operations',
        :queue_name  => 'generic',
        :zone        => ems.my_zone,
        :args        => [{:name => 'updated_config', :task_id => task_id}, nil]
      )
    end
  end
end
