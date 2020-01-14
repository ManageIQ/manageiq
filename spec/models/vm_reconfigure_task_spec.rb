RSpec.describe VmReconfigureTask do
  let(:user) { FactoryBot.create(:user_with_group) }
  let(:ems_vmware)    { FactoryBot.create(:ems_vmware, :zone => zone2) }
  let(:host_hardware) { FactoryBot.build(:hardware, :cpu_total_cores => 40, :cpu_sockets => 10, :cpu_cores_per_socket => 4) }
  let(:host)          { FactoryBot.build(:host, :hardware => host_hardware) }
  let(:vm_hardware)   { FactoryBot.build(:hardware, :virtual_hw_version => "07") }
  let(:vm) { FactoryBot.create(:vm_vmware, :hardware => vm_hardware, :host => host) }
  let(:request_options) { {} }

  let(:request) do
    VmReconfigureRequest.create(:requester    => user,
                                :options      => {:src_ids => [vm.id]}.merge(request_options),
                                :request_type => 'vm_reconfigure')
  end

  let(:task) do
    VmReconfigureTask.create(:userid       => user.userid,
                             :miq_request  => request,
                             :source       => vm,
                             :request_type => 'vm_reconfigure')
  end

  describe ".base_model" do
    it "should return VmReconfigureTask" do
      expect(VmReconfigureTask.base_model).to eq(VmReconfigureTask)
    end
  end

  describe "#after_request_task_create" do
    it "should set the task description" do
      task.after_request_task_create
      expect(task.description).to include("VM Reconfigure for: #{vm} - ")
    end
  end

  context "Single Disk add " do
    let(:request_options) { {:disk_add => [{"disk_size_in_mb" => "33", "persistent" => "true"}]} }

    describe ".get_description" do
      it "should get the task description" do
        expect(VmReconfigureTask.get_description(request)).to eq("VM Reconfigure for: #{vm} - Add Disks: 1 : #{request.options[:disk_add][0]["disk_size_in_mb"].to_i.megabytes.to_s(:human_size)} ")
      end
    end
  end

  context "Multiple Disk add " do
    let(:request_options) do
      {:disk_add => [{"disk_size_in_mb" => "33", "persistent" => "true"},
                     {"disk_size_in_mb" => "44", "persistent" => "true"}]}
    end

    describe ".get_description" do
      it "should get the task description" do
        expect(VmReconfigureTask.get_description(request)).to eq("VM Reconfigure for: #{vm} - Add Disks: 2 : #{request.options[:disk_add][0]["disk_size_in_mb"].to_i.megabytes.to_s(:human_size)}, "\
          "#{request.options[:disk_add][1]["disk_size_in_mb"].to_i.megabytes.to_s(:human_size)} ")
      end
    end
  end
end
