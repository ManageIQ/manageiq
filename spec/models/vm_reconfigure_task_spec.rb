require "spec_helper"

describe VmReconfigureTask do
  context "#build_config_spec" do
    before do
      @options = {:vm_memory => '1024', :number_of_cpus => '8', :cores_per_socket => '2'}
      @vm      = FactoryGirl.create(:vm_vmware, :hardware => FactoryGirl.create(:hardware, :virtual_hw_version => "07"))
      @task    = FactoryGirl.create(:vm_reconfigure_task, :options => @options, :source => @vm)
    end
    subject { @task.build_config_spec }

    it "memoryMB" do
      expect(subject["memoryMB"]).to eq(1024)
    end

    it "numCPUs" do
      expect(subject["numCPUs"]).to eq(8)
    end

    context "numCoresPerSocket" do
      it "virtual_hw_version = 07" do
        expect(subject["extraConfig"]).to eq([{"key" => "cpuid.coresPerSocket", "value" => "2"}])
      end

      it "virtual_hw_version != 07" do
        @vm.hardware.update_attributes(:virtual_hw_version => "08")
        expect(subject["numCoresPerSocket"]).to eq(2)
      end

      it "vm_redhat" do
        vm     = FactoryGirl.create(:vm_redhat, :hardware => FactoryGirl.create(:hardware))
        task   = FactoryGirl.create(:vm_reconfigure_task, :options => @options, :source => vm)
        result = task.build_config_spec
        expect(result["numCoresPerSocket"]).to eq(2)
      end
    end
  end
end
