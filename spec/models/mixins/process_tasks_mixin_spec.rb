describe ProcessTasksMixin do
  describe ".process_tasks" do
    before(:each) do
      @guid, @server, @zone = EvmSpecHelper.create_guid_miq_server_zone
      @host = FactoryGirl.create(:host_vmware, :name => "test_host",    :hostname   => "test_host", :state => 'on')
    end

    it "deletes VM via call to MiqTask#queue_callback and verifies message" do
      @vm1 = FactoryGirl.create(:vm_vmware, :host => @host, :name => "VM-mini1")

      @vm1.class.process_tasks(:task => "destroy", :userid => "system", :ids => [@vm1.id])

      expect(MiqQueue.count).to eq(1)
      @msg1 = MiqQueue.first
      status, message, result = @msg1.deliver

      expect(@msg1.state).to eq("ready")
      expect(@msg1.class_name).to eq("ManageIQ::Providers::Vmware::InfraManager::Vm")
      @msg1.args.each do |h|
        expect(h[:task]).to eq("destroy")
        expect(h[:ids]).to eq([@vm1.id])
        expect(h[:userid]).to eq("system")
      end

      @msg1.destroy
      expect(MiqQueue.count).to eq(1)
      @msg2 = MiqQueue.first
      status, message, result = @msg2.deliver
      expect_any_instance_of(MiqTask).to receive(:queue_callback).with("Finished", status, message, result)
      @msg2.delivered(status, message, result)
    end

    it "deletes VM via call to MiqTask#queue_callback and successfully saves object image via YAML.dump" do
      @vm2 = FactoryGirl.create(:vm_vmware, :host => @host, :name => "VM-mini2")
      @vm2.destroy
      expect { YAML.dump(@vm2) }.not_to raise_error
    end
  end
end
