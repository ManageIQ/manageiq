RSpec.describe ConversionHost, :v2v do
  let(:conversion_host) { FactoryBot.create(:conversion_host, :resource => vm) }
  let(:conversion_host_ssh) { FactoryBot.create(:conversion_host, :resource => vm, :ssh_transport_supported => true) }
  let(:conversion_host_vddk) { FactoryBot.create(:conversion_host, :resource => vm, :vddk_transport_supported => true) }
  let(:params) do
    {
      :name          => 'transformer',
      :resource_type => vm.class.base_class.name,
      :resource_id   => vm.id,
      :resource      => vm
    }
  end

  context "processing configuration requests" do
    let(:vm) { FactoryBot.create(:vm_openstack) }

    before(:each) do
      allow(ConversionHost).to receive(:new).and_return(conversion_host)
    end

    context ".enable" do
      let(:expected_notify) do
        {
          :type    => :conversion_host_config_success,
          :options => {
            :op_name => "enable",
            :op_arg  => "type=#{params[:resource_type]} id=#{params[:resource_id]}"
          }
        }
      end

      it "to succeed and send notification" do
        allow(conversion_host).to receive(:enable_conversion_host_role)
        expect(Notification).to receive(:create).with(expected_notify)
        expect(described_class.enable(params)).to be_a(described_class)
      end

      it "to fail and send notification" do
        expected_notify[:type] = :conversion_host_config_failure
        allow(conversion_host).to receive(:enable_conversion_host_role).and_raise
        expect(Notification).to receive(:create).with(expected_notify)
        expect { described_class.enable(params) }.to raise_error(StandardError)
      end

      context "transport method is SSH" do
        let(:conversion_host) { conversion_host_ssh }

        it "tags the associated resource as expected" do
          allow(conversion_host).to receive(:enable_conversion_host_role)
          taggings = conversion_host.resource.taggings
          tag_names = taggings.map { |tagging| tagging.tag.name }

          expect(tag_names).to contain_exactly(
            '/user/v2v_transformation_host/true',
            '/user/v2v_transformation_method/ssh'
          )
        end
      end

      context "transport method is VDDK" do
        let(:conversion_host) { conversion_host_vddk }

        it "tags the associated resource as expected" do
          allow(conversion_host).to receive(:enable_conversion_host_role)
          taggings = conversion_host.resource.taggings
          tag_names = taggings.map { |tagging| tagging.tag.name }

          expect(tag_names).to contain_exactly(
            '/user/v2v_transformation_host/true',
            '/user/v2v_transformation_method/vddk'
          )
        end
      end
    end

    context "#disable" do
      let(:expected_notify) do
        {
          :type    => :conversion_host_config_success,
          :options => {
            :op_name => "disable",
            :op_arg  => "type=#{vm.class.name} id=#{vm.id}"
          }
        }
      end

      it "to succeed and send notification" do
        allow(conversion_host).to receive(:disable_conversion_host_role)
        expect(Notification).to receive(:create).with(expected_notify)
        conversion_host.disable
      end

      it "to raise if active tasks exist" do
        expected_notify[:type] = :conversion_host_config_failure
        FactoryBot.create(:service_template_transformation_plan_task, :conversion_host => conversion_host, :state => 'migrate')
        expect(Notification).to receive(:create).with(expected_notify)
        expect { conversion_host.disable }.to raise_error(StandardError, "There are active migration tasks running on this conversion host")
      end

      it "tags the associated resource as expected" do
        allow(conversion_host).to receive(:disable_conversion_host_role)
        expect(Notification).to receive(:create).with(expected_notify)
        conversion_host.disable
        taggings = conversion_host.resource.taggings
        tag_names = taggings.map { |tagging| tagging.tag.name }

        expect(tag_names).to contain_exactly('/user/v2v_transformation_host/false')
      end
    end
  end

  context "queuing configuration requests" do
    let(:ext_management_system) { FactoryBot.create(:ext_management_system) }
    let(:vm) { FactoryBot.create(:vm_openstack, :ext_management_system => ext_management_system) }
    let(:expected_task_action) { "Configuring a conversion_host: operation=#{op} resource=(name: #{vm.name} type: #{vm.class.name} id: #{vm.id})" }

    context ".enable_queue" do
      let(:op) { 'enable' }

      it "raises if resource has no hostname nor IP address" do
        allow(vm).to receive(:hostname).and_return(nil)
        allow(vm).to receive(:ipaddresses).and_return([])
        expect { described_class.enable_queue(:resource => vm) }.to raise_error("Vm '#{vm.name}' doesn't have a hostname or IP address in inventory")
      end

      it "raises an error if the resource is already configured as a conversion host" do
        allow(vm).to receive(:ipaddresses).and_return(['10.0.0.1'])
        FactoryBot.create(:conversion_host, :resource => vm)
        expect { described_class.enable_queue(:resource => vm) }.to raise_error("the resource '#{vm.name}' is already configured as a conversion host")
      end

      it "to queue with a task" do
        allow(vm).to receive(:ipaddresses).and_return(['10.0.0.1'])
        task_id = described_class.enable_queue(params)
        expected_context_data = {:request_params => params.except(:resource)}

        expect(MiqTask.find(task_id)).to have_attributes(:name => expected_task_action, :context_data => expected_context_data)
        expect(MiqQueue.first).to have_attributes(
          :args        => [params.merge(:task_id => task_id).except(:resource), nil],
          :class_name  => described_class.name,
          :method_name => "enable",
          :priority    => MiqQueue::NORMAL_PRIORITY,
          :role        => "ems_operations",
          :zone        => vm.ext_management_system.my_zone
        )
      end

      it "rejects ssh key information as context data" do
        allow(vm).to receive(:ipaddresses).and_return(['10.0.0.1'])
        task_id = described_class.enable_queue(params.merge(:conversion_host_ssh_private_key => 'xxx', :vmware_ssh_private_key => 'yyy'))
        expected_context_data = {:request_params => params.except(:resource)}

        expect(MiqTask.find(task_id)).to have_attributes(:name => expected_task_action, :context_data => expected_context_data)
      end
    end

    context "#disable_queue" do
      let(:op) { 'disable' }

      let(:expected_notify) do
        {
          :type    => :conversion_host_config_success,
          :options => {
            :op_name => "disable",
            :op_arg  => "type=#{vm.class.name} id=#{vm.id}"
          }
        }
      end

      it "to queue with a task" do
        task_id = conversion_host.disable_queue
        expect(MiqTask.find(task_id)).to have_attributes(:name => expected_task_action)
        expect(MiqQueue.first).to have_attributes(
          :args        => [{:task_id => task_id}, nil],
          :class_name  => described_class.name,
          :instance_id => conversion_host.id,
          :method_name => "disable",
          :priority    => MiqQueue::NORMAL_PRIORITY,
          :role        => "ems_operations",
          :zone        => conversion_host.resource.ext_management_system.my_zone
        )
      end

      it "calls the disable method if delivered" do
        allow(conversion_host).to receive(:disable_conversion_host_role)
        allow(ConversionHost).to receive(:find).with(conversion_host.id).and_return(conversion_host)

        expect(Notification).to receive(:create).with(expected_notify)
        conversion_host.disable_queue
        expect(MiqQueue.first.deliver).to include("ok")
      end
    end
  end
end
