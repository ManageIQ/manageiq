describe ServiceHelper::TextualSummary do
  describe ".textual_orchestration_stack" do
    let(:os_cloud) { FactoryGirl.create(:orchestration_stack_cloud, :name => "cloudstack1") }
    let(:os_infra) { FactoryGirl.create(:orchestration_stack_openstack_infra, :name => "infrastack1") }

    before do
      login_as FactoryGirl.create(:user)
    end

    subject { textual_orchestration_stack }
    it 'contains the link to the associated cloud stack' do
      @record = FactoryGirl.create(:service)
      allow(@record).to receive(:orchestration_stack).and_return(os_cloud)
      expect(textual_orchestration_stack).to eq(os_cloud)
    end

    it 'contains the link to the associated infra stack' do
      @record = FactoryGirl.create(:service)
      allow(@record).to receive(:orchestration_stack).and_return(os_infra)
      expect(textual_orchestration_stack).to eq(os_infra)
    end

    it 'contains no link for an invalid stack' do
      os_infra.id = nil
      @record = FactoryGirl.create(:service)
      allow(@record).to receive(:orchestration_stack).and_return(os_infra)
      expect(textual_orchestration_stack[:link]).to be_nil
    end
  end

  describe ".textual_agregate_all_vms" do
    let(:vm) { FactoryGirl.create(:vm_vmwware, :name => "vm1") }

    before do
      login_as FactoryGirl.create(:user)
      @record = FactoryGirl.create(:service)
    end

    subject { textual_aggregate_all_vm_cpus }
    it 'displays 0 for nil aggregate_all_vm_cpus' do
      allow(@record).to receive(:aggregate_all_vm_cpus).and_return(nil)
      expect(textual_aggregate_all_vm_cpus).to eq(:label => "CPU", :value => nil)
    end

    subject { textual_aggregate_all_vm_memory }
    it 'displays 0 Bytes for nil aggregate_all_vm_memory' do
      allow(@record).to receive(:aggregate_all_vm_memory).and_return(nil)
      expect(textual_aggregate_all_vm_memory).to eq(:label => "Memory", :value => "0 Bytes")
    end

    subject { textual_aggregate_all_vm_disk_count }
    it 'displays 0 for nil aggregate_all_vm_disk_count' do
      allow(@record).to receive(:aggregate_all_vm_disk_count).and_return(nil)
      expect(textual_aggregate_all_vm_disk_count).to eq(:label => "Disk Count", :value => nil)
    end

    subject { textual_aggregate_all_vm_disk_space_allocated }
    it 'displays 0 Bytes for nil aggregate_all_vm_disk_space_allocated' do
      allow(@record).to receive(:aggregate_all_vm_disk_space_allocated).and_return(nil)
      expect(textual_aggregate_all_vm_disk_space_allocated).to eq(:label => "Disk Space Allocated", :value => "0 Bytes")
    end

    subject { textual_aggregate_all_vm_disk_space_used }
    it 'displays 0 Bytes for nil aggregate_all_vm_disk_space_used' do
      allow(@record).to receive(:aggregate_all_vm_disk_space_used).and_return(nil)
      expect(textual_aggregate_all_vm_disk_space_used).to eq(:label => "Disk Space Used", :value => "0 Bytes")
    end

    subject { textual_aggregate_all_vm_memory_on_disk }
    it 'displays 0 Bytes for nil aggregate_all_vm_memory_on_disk' do
      allow(@record).to receive(:aggregate_all_vm_memory_on_disk).and_return(nil)
      expect(textual_aggregate_all_vm_memory_on_disk).to eq(:label => "Memory on Disk", :value => "0 Bytes")
    end
  end
end
