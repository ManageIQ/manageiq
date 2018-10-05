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
    end

    describe "#check_concurrent_tasks" do
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
  end

  context "resource provider is rhevm" do
    let(:ems) { FactoryGirl.create(:ems_redhat, :zone => FactoryGirl.create(:zone)) }
    let(:host) { FactoryGirl.create(:host, :ext_management_system => ems) }
    let(:conversion_host) { FactoryGirl.create(:conversion_host, :resource => host, :vddk_transport_supported => true) }

    context "host userid is nil" do
      before { allow(host).to receive(:authentication_userid).and_return(nil) }
      it { expect(conversion_host.check_resource_credentials).to eq(false) }
    end

    context "host userid is set" do
      before { allow(host).to receive(:authentication_userid).and_return('root') }

      context "and host password is nil" do
        before { allow(host).to receive(:authentication_password).and_return(nil) }
        it { expect(conversion_host.check_resource_credentials).to eq(false) }
      end

      context "and host password is set" do
        before { allow(host).to receive(:authentication_password).and_return('password') }
        it { expect(conversion_host.check_resource_credentials).to eq(true) }
      end
    end
  end

  context "resource provider is openstack" do
    let(:ems) { FactoryGirl.create(:ems_openstack, :zone => FactoryGirl.create(:zone)) }
    let(:vm) { FactoryGirl.create(:vm, :ext_management_system => ems) }
    let(:conversion_host) { FactoryGirl.create(:conversion_host, :resource => vm, :vddk_transport_supported => true) }

    context "ems authentications is empty" do
      it { expect(conversion_host.check_resource_credentials).to be(false) }
    end

    context "ems authentications contains ssh_auth" do
      let(:ssh_auth) { FactoryGirl.create(:authentication_ssh_keypair, :resource => ems) }

      it "with fake auth" do
        allow(ems).to receive(:authentications).and_return(ssh_auth)
        allow(ssh_auth).to receive(:where).with(:authype => 'ssh_keypair').and_return(ssh_auth)
        allow(ssh_auth).to receive(:where).and_return(ssh_auth)
        allow(ssh_auth).to receive(:not).with(:userid => nil, :auth_key => nil).and_return([ssh_auth])
        expect(conversion_host.check_resource_credentials).to be(true)
      end
    end
  end
end
