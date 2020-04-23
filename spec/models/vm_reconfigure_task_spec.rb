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
    let(:request_options) { {:disk_add => [{"disk_size_in_mb" => "33", "persistent" => "true", "type" => "thin"}.with_indifferent_access]} }
    let(:description_partial) do
      "Add Disks: 1 : #{request.options[:disk_add][0]["disk_size_in_mb"].to_i.megabytes.to_s(:human_size)}, Type: "\
    "#{request.options[:disk_add][0]["type"]} "
    end

    it_behaves_like ".get_description"
  end

  context "Multiple Disk add " do
    let(:request_options) do
      {:disk_add => [{"disk_size_in_mb" => "33", "persistent" => "true", "type" => "thin"}.with_indifferent_access,
                     {"disk_size_in_mb" => "44", "persistent" => "true", "type" => "thick"}.with_indifferent_access]}
    end
    let(:description_partial) do
      "Add Disks: 2 : #{request.options[:disk_add][0]["disk_size_in_mb"].to_i.megabytes.to_s(:human_size)}, Type: "\
      "#{request.options[:disk_add][0]["type"]}, #{request.options[:disk_add][1]["disk_size_in_mb"].to_i.megabytes.to_s(:human_size)}, Type: "\
      "#{request.options[:disk_add][1]["type"]} "
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
      {:disk_remove => [{:disk_name => "e88da36f", :delete_backing => false}.with_indifferent_access],
       :disk_resize => [{:disk_name => "e88da36f", :disk_size_in_mb => 153_600}.with_indifferent_access]}
    end
    let(:description_partial) { "Remove Disks: 1, Resize Disks: 1" }

    it_behaves_like ".get_description"
  end

  context "Network" do
    let(:request_options) do
      {:network_adapter_add    => [
        {:cloud_network => 'vApp Network Name', :name => 'VM Name#NIC#2'}.with_indifferent_access,
        {:cloud_network => nil, :name => 'VM Name#NIC#3'}.with_indifferent_access
      ],
       :network_adapter_remove => [{:network => {:name => 'VM Name#NIC#0'}.with_indifferent_access}],
       :network_adapter_edit   => [{:network => "NFS Network", :name => "Network adapter 1"}.with_indifferent_access]}
    end
    let(:description_partial) { "Add Network Adapters: 2, Remove Network Adapters: 1, Edit Network Adapters: 1" }

    it_behaves_like ".get_description"
  end

  context "CDROM" do
    let(:request_options) do
      {:cdrom_connect    => [
        {:device_name => "CD/DVD drive 1",
         :filename    => "[NFS Share] ISO/centos.iso",
         :storage_id  => 1234}.with_indifferent_access
      ],
       :cdrom_disconnect => [{:device_name => "CD/DVD drive 2"}.with_indifferent_access]}
    end
    let(:description_partial) { "Attach CD/DVDs: 1, Detach CD/DVDs: 1" }

    it_behaves_like ".get_description"
  end
end
