RSpec.describe "VM Snapshotting" do
  before { EvmSpecHelper.local_miq_server }
  let(:vm) { FactoryBot.create(:vm) }

  describe ".v_total_snapshots" do
    it "counts many" do
      FactoryBot.create_list(:snapshot, 2, :create_time => 1.minute.ago, :vm_or_template => vm)
      expect(vm.v_total_snapshots).to eq(2)
    end

    it "counts none" do
      expect(vm.v_total_snapshots).to eq(0)
    end
  end

  describe ".v_snapshot_oldest_name" do
    it "returns value" do
      FactoryBot.create(:snapshot, :create_time => 1.minute.ago, :vm_or_template => vm, :name => "the name")
      expect(vm.v_snapshot_oldest_name).to eq("the name")
    end

    it "supports nil" do
      expect(vm.v_snapshot_oldest_name).to be_nil
    end
  end

  describe ".v_snapshot_oldest_description" do
    it "returns value" do
      FactoryBot.create(:snapshot, :create_time => 1.minute.ago, :vm_or_template => vm, :description => "the description")
      expect(vm.v_snapshot_oldest_description).to eq("the description")
    end

    it "supports nil" do
      expect(vm.v_snapshot_oldest_description).to be_nil
    end
  end

  describe ".v_snapshot_oldest_total_size" do
    it "returns value" do
      FactoryBot.create(:snapshot, :create_time => 1.minute.ago, :vm_or_template => vm, :total_size => 500)
      expect(vm.v_snapshot_oldest_total_size).to eq(500)
    end

    it "supports nil" do
      expect(vm.v_snapshot_oldest_total_size).to be_nil
    end
  end


  describe ".v_snapshot_newest_name" do
    it "returns value" do
      FactoryBot.create(:snapshot, :create_time => 1.minute.ago, :vm_or_template => vm, :name => "the name")
      expect(vm.v_snapshot_newest_name).to eq("the name")
    end

    it "supports nil" do
      expect(vm.v_snapshot_newest_name).to be_nil
    end
  end

  describe ".v_snapshot_newest_description" do
    it "returns value" do
      FactoryBot.create(:snapshot, :create_time => 1.minute.ago, :vm_or_template => vm, :description => "the description")
      expect(vm.v_snapshot_newest_description).to eq("the description")
    end

    it "supports nil" do
      expect(vm.v_snapshot_newest_description).to be_nil
    end
  end

  describe ".v_snapshot_newest_total_size" do
    it "returns value" do
      FactoryBot.create(:snapshot, :create_time => 1.minute.ago, :vm_or_template => vm, :total_size => 500)
      expect(vm.v_snapshot_newest_total_size).to eq(500)
    end

    it "supports nil" do
      expect(vm.v_snapshot_newest_total_size).to be_nil
    end
  end
end
