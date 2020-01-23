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

  shared_examples_for ".get_description" do
    it "should get the task description" do
      expect(VmReconfigureTask.get_description(request)).to include(description_partial)
    end
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
    let(:description_partial) { "Add Disks: 1 : #{request.options[:disk_add][0]["disk_size_in_mb"].to_i.megabytes.to_s(:human_size)} " }

    it_behaves_like ".get_description"
  end

  context "Multiple Disk add " do
    let(:request_options) do
      {:disk_add => [{"disk_size_in_mb" => "33", "persistent" => "true"},
                     {"disk_size_in_mb" => "44", "persistent" => "true"}]}
    end
    let(:description_partial) do
      "Add Disks: 2 : #{request.options[:disk_add][0]["disk_size_in_mb"].to_i.megabytes.to_s(:human_size)}, "\
      "#{request.options[:disk_add][1]["disk_size_in_mb"].to_i.megabytes.to_s(:human_size)} "
    end

    it_behaves_like ".get_description"
  end

  context "Hardware Properties" do
    let(:request_options) do
      {:vm_memory         => 512,
       :number_of_sockets => 2,
       :cores_per_socket  => 4,
       :number_of_cpus    => 1}
    end
    let(:description_partial) { "Memory: 512 MB, Processor Sockets: 2, Processor Cores Per Socket: 4, Total Processors: 1" }

    it_behaves_like ".get_description"
  end

  context "Disk remove/resize" do
    let(:request_options) do
      {:disk_remove => [1],
       :disk_resize => [1, 2]}
    end
    let(:description_partial) { "Remove Disks: 1, Resize Disks: 2" }

    it_behaves_like ".get_description"
  end

  context "Network" do
    let(:request_options) do
      {:network_adapter_add    => [1],
       :network_adapter_remove => [1, 2],
       :network_adapter_edit   => [1, 2, 3]}
    end
    let(:description_partial) { "Add Network Adapters: 1, Remove Network Adapters: 2, Edit Network Adapters: 3" }

    it_behaves_like ".get_description"
  end

  context "CDROM" do
    let(:request_options) do
      {:cdrom_connect    => [1],
       :cdrom_disconnect => [1, 2]}
    end
    let(:description_partial) { "Attach CD/DVDs: 1, Detach CD/DVDs: 2" }

    it_behaves_like ".get_description"
  end
end
