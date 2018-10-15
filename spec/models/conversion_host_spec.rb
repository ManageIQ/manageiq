require "MiqSshUtil"

describe ConversionHost do
  let(:apst) { FactoryGirl.create(:service_template_ansible_playbook) }

  context "provider independent methods" do
    let(:host) { FactoryGirl.create(:host) }
    let(:vm) { FactoryGirl.create(:vm_or_template) }
    let(:conversion_host_1) { FactoryGirl.create(:conversion_host, :resource => host) }
    let(:conversion_host_2) { FactoryGirl.create(:conversion_host, :resource => vm) }
    let(:task_1) { FactoryGirl.create(:service_template_transformation_plan_task, :state => 'active', :conversion_host => conversion_host_1) }
    let(:task_2) { FactoryGirl.create(:service_template_transformation_plan_task, :conversion_host => conversion_host_1) }
    let(:task_3) { FactoryGirl.create(:service_template_transformation_plan_task, :state => 'active', :conversion_host => conversion_host_2) }

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
        allow(conversion_host_1).to receive(:check_ssh_connection).and_return(true)
        allow(conversion_host_1).to receive(:check_concurrent_tasks).and_return(true)
        expect(conversion_host_1.eligible?).to eq(false)
      end

      it "fails when no source transport method is enabled" do
        allow(conversion_host_1).to receive(:source_transport_method).and_return('vddk')
        allow(conversion_host_1).to receive(:check_ssh_connection).and_return(false)
        allow(conversion_host_1).to receive(:check_concurrent_tasks).and_return(true)
        expect(conversion_host_1.eligible?).to eq(false)
      end

      it "fails when no source transport method is enabled" do
        allow(conversion_host_1).to receive(:source_transport_method).and_return('vddk')
        allow(conversion_host_1).to receive(:check_ssh_connection).and_return(true)
        allow(conversion_host_1).to receive(:check_concurrent_tasks).and_return(false)
        expect(conversion_host_1.eligible?).to eq(false)
      end

      it "succeeds when all criteria are met" do
        allow(conversion_host_1).to receive(:source_transport_method).and_return('vddk')
        allow(conversion_host_1).to receive(:check_ssh_connection).and_return(true)
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
    let(:ems) { FactoryGirl.create(:ems_redhat, :zone => FactoryGirl.create(:zone)) }
    let(:host) { FactoryGirl.create(:host_redhat, :ext_management_system => ems) }
    let(:conversion_host) { FactoryGirl.create(:conversion_host, :resource => host, :vddk_transport_supported => true) }

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
    let(:ems) { FactoryGirl.create(:ems_openstack, :zone => FactoryGirl.create(:zone)) }
    let(:vm) { FactoryGirl.create(:vm_openstack, :ext_management_system => ems) }
    let(:conversion_host) { FactoryGirl.create(:conversion_host, :resource => vm, :vddk_transport_supported => true) }

    context "ems authentications is empty" do
      it { expect(conversion_host.check_ssh_connection).to be(false) }
    end

    context "ems authentications contains ssh_auth" do
      let(:ssh_auth) { FactoryGirl.create(:authentication_ssh_keypair, :resource => ems) }

      before do
        allow(ems).to receive(:authentications).and_return(ssh_auth)
        allow(ssh_auth).to receive(:where).with(:authype => 'ssh_keypair').and_return(ssh_auth)
        allow(ssh_auth).to receive(:where).and_return(ssh_auth)
        allow(ssh_auth).to receive(:not).with(:userid => nil, :auth_key => nil).and_return([ssh_auth])
      end

      it_behaves_like "#check_ssh_connection"
    end
  end
end
