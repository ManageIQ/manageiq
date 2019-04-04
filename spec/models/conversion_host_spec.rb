require "MiqSshUtil"

describe ConversionHost do
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
        allow(conversion_host_1).to receive(:verify_credentials).and_return(true)
        allow(conversion_host_1).to receive(:check_concurrent_tasks).and_return(true)
        expect(conversion_host_1.eligible?).to eq(false)
      end

      it "fails when no source transport method is enabled" do
        allow(conversion_host_1).to receive(:source_transport_method).and_return('vddk')
        allow(conversion_host_1).to receive(:verify_credentials).and_return(false)
        allow(conversion_host_1).to receive(:check_concurrent_tasks).and_return(true)
        expect(conversion_host_1.eligible?).to eq(false)
      end

      it "fails when no source transport method is enabled" do
        allow(conversion_host_1).to receive(:source_transport_method).and_return('vddk')
        allow(conversion_host_1).to receive(:verify_credentials).and_return(true)
        allow(conversion_host_1).to receive(:check_concurrent_tasks).and_return(false)
        expect(conversion_host_1.eligible?).to eq(false)
      end

      it "succeeds when all criteria are met" do
        allow(conversion_host_1).to receive(:source_transport_method).and_return('vddk')
        allow(conversion_host_1).to receive(:verify_credentials).and_return(true)
        allow(conversion_host_1).to receive(:check_concurrent_tasks).and_return(true)
        expect(conversion_host_1.eligible?).to eq(true)
      end
    end

    context "#check_concurrent_tasks" do
      context "default max concurrent tasks is equal to current active tasks" do
        before { stub_settings_merge(:transformation => {:limits => {:max_concurrent_tasks_per_host => 1}}) }
        it { expect(conversion_host_1.check_concurrent_tasks).to eq(false) }
      end

      context "default max concurrent tasks is greater than current active tasks" do
        before { stub_settings_merge(:transformation => {:limits => {:max_concurrent_tasks_per_host => 10}}) }
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
        expect(conversion_host_1.kill_process('1234', 'KILL')).to eq(false)
      end

      it "returns true if if kill command succeeded" do
        allow(conversion_host_1).to receive(:connect_ssh)
        expect(conversion_host_1.kill_process('1234', 'KILL')).to eq(true)
      end
    end
  end

  shared_examples_for "#check_ssh_connection" do
    it "fails when SSH send an error" do
      allow(conversion_host).to receive(:connect).and_raise('Unexpected failure')
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
  end

  context "resource provider is openstack" do
    let(:ems) { FactoryBot.create(:ems_openstack, :zone => FactoryBot.create(:zone)) }
    let(:vm) { FactoryBot.create(:vm_openstack, :ext_management_system => ems) }
    let(:conversion_host) { FactoryBot.create(:conversion_host, :resource => vm, :vddk_transport_supported => true) }

    context "ems authentications is empty" do
      it { expect(conversion_host.check_ssh_connection).to be(false) }
    end

    context "ems authentications contains ssh_auth" do
      let(:ssh_auth) { FactoryBot.create(:authentication_ssh_keypair, :resource => ems) }

      before do
        allow(ems).to receive(:authentications).and_return(ssh_auth)
        allow(ssh_auth).to receive(:where).with(:authype => 'ssh_keypair').and_return(ssh_auth)
        allow(ssh_auth).to receive(:where).and_return(ssh_auth)
        allow(ssh_auth).to receive(:not).with(:userid => nil, :auth_key => nil).and_return([ssh_auth])
      end

      it_behaves_like "#check_ssh_connection"
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
    let(:conversion_host_vm) { FactoryBot.create(:conversion_host, :resource => vm) }
    let(:auth_authkey) { FactoryBot.create(:authentication_ssh_keypair, :resource => conversion_host_vm) }

    it "finds associated authentications" do
      expect(conversion_host_vm.authentications).to contain_exactly(auth_authkey)
    end

    it "allows a resource to add an authentication" do
      auth_authkey2 = FactoryBot.create(:authentication_ssh_keypair)
      conversion_host_vm.authentications << auth_authkey2
      expect(conversion_host_vm.authentications).to contain_exactly(auth_authkey, auth_authkey2)
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

    it "works as expected if there is an associated validation that is invalid" do
      authentication = FactoryBot.create(:authentication_ssh_keypair)
      conversion_host_vm.authentications << authentication
      allow(Net::SSH).to receive(:start).and_raise(Net::SSH::AuthenticationFailed.new)
      expect { conversion_host_vm.verify_credentials }.to raise_error(MiqException::MiqInvalidCredentialsError)
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

  context "#get_conversion_state" do
    let(:vm) { FactoryBot.create(:vm_openstack) }
    let(:conversion_host) { FactoryBot.create(:conversion_host, :resource => vm) }
    let(:path) { 'some_path' }

    it "works as expected if the connection is successful and the JSON is valid" do
      allow(conversion_host).to receive(:connect_ssh).and_return({:alpha => {:beta => 'hello'}}.to_json)
      expect(conversion_host.get_conversion_state(path)).to eql('alpha' => {'beta' => 'hello'})
    end

    it "works as expected if the connection is successful but the JSON is invalid" do
      allow(conversion_host).to receive(:connect_ssh).and_return('bogus')
      expected_message = "Could not parse conversion state data from file '#{path}': bogus"
      expect { conversion_host.get_conversion_state(path) }.to raise_error(expected_message)
    end

    it "works as expected if the connection is unsuccessful" do
      allow(conversion_host).to receive(:connect_ssh).and_raise(MiqException::MiqInvalidCredentialsError)
      expected_message = "Failed to connect and retrieve conversion state data from file '#{path}'"
      expect { conversion_host.get_conversion_state(path) }.to raise_error(/#{expected_message}/)
    end

    it "works as expected if an unknown error occurs" do
      allow(conversion_host).to receive(:connect_ssh).and_raise(StandardError)
      expected_message = "Error retrieving and parsing conversion state file '#{path}' from '#{vm.name}'"
      expect { conversion_host.get_conversion_state(path) }.to raise_error(/#{expected_message}/)
    end
  end
end
