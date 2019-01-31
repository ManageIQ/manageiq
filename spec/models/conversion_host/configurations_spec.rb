describe ConversionHost do
  let(:conversion_host) { FactoryBot.create(:conversion_host, :resource => vm) }
  let(:params) do
    {
      :name          => 'transformer',
      :resource_type => vm.class.name,
      :resource_id   => vm.id,
      :resource      => vm
    }
  end

  context "processing configuration requests" do
    let(:vm) { FactoryBot.create(:vm) }
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

      it "to fail and send notification" do
        expected_notify[:type] = :conversion_host_config_failure
        allow(conversion_host).to receive(:disable_conversion_host_role).and_raise
        expect(Notification).to receive(:create).with(expected_notify)
        expect { conversion_host.disable }.to raise_error(StandardError)
      end
    end
  end

  context "queuing configuration requests" do
    let(:ext_management_system) { FactoryBot.create(:ext_management_system) }
    let(:vm) { FactoryBot.create(:vm, :ext_management_system => ext_management_system) }
    let(:expected_task_action) { "Configuring a conversion_host: operation=#{op} resource=(type: #{vm.class.name} id:#{vm.id})" }

    context ".enable_queue" do
      let(:op) { 'enable' }

      it "to queue with a task" do
        task_id = described_class.enable_queue(params)
        expect(MiqTask.find(task_id)).to have_attributes(:name => expected_task_action)
        expect(MiqQueue.first).to have_attributes(
          :args        => [params.merge(:task_id => task_id).except(:resource)],
          :class_name  => described_class.name,
          :method_name => "enable",
          :priority    => MiqQueue::NORMAL_PRIORITY,
          :role        => "ems_operations",
          :zone        => vm.ext_management_system.my_zone
        )
      end
    end

    context "#disable_queue" do
      let(:op) { 'disable' }

      it "to queue with a task" do
        task_id = conversion_host.disable_queue
        expect(MiqTask.find(task_id)).to have_attributes(:name => expected_task_action)
        expect(MiqQueue.first).to have_attributes(
          :args        => [],
          :class_name  => described_class.name,
          :instance_id => conversion_host.id,
          :method_name => "disable",
          :priority    => MiqQueue::NORMAL_PRIORITY,
          :role        => "ems_operations",
          :zone        => conversion_host.resource.ext_management_system.my_zone
        )
      end
    end
  end
end
