RSpec.describe PhysicalServer do
  let(:attrs)    { { :manufacturer => 'manu', :model => 'model' } }
  let!(:binary1) { FactoryBot.create(:firmware_binary) }
  let!(:binary2) { FactoryBot.create(:firmware_binary) }
  let!(:target)  { FactoryBot.create(:firmware_target, **attrs, :firmware_binaries => [binary1]) }

  subject { FactoryBot.create(:physical_server, :with_asset_detail) }

  include_examples "MiqPolicyMixin"

  describe '#compatible_firmware_binaries' do
    before { subject.asset_detail.update(**attrs) }

    it 'when compatible are found' do
      expect(subject.compatible_firmware_binaries).to eq([binary1])
    end

    it 'when no compatible are found' do
      subject.asset_detail.update(:model => 'other-model')
      expect(subject.compatible_firmware_binaries).to eq([])
    end
  end

  describe '#firmware_compatible?' do
    it 'when yes' do
      expect(subject.firmware_compatible?(binary1)).to eq(true)
    end

    it 'when no' do
      expect(subject.firmware_compatible?(binary2)).to eq(false)
    end
  end

  describe "#queue_name_for_ems_operations" do
    context "with an active configured_system" do
      let(:manager)         { FactoryBot.create(:physical_infra) }
      let(:physical_server) { FactoryBot.create(:physical_server, :with_asset_detail, :ext_management_system => manager) }

      it "uses the manager's queue_name_for_ems_operations" do
        expect(physical_server.queue_name_for_ems_operations).to eq(manager.queue_name_for_ems_operations)
      end
    end

    context "with an archived configured_system" do
      let(:physical_server) { FactoryBot.create(:physical_server, :with_asset_detail) }

      it "uses the manager's queue_name_for_ems_operations" do
        expect(physical_server.queue_name_for_ems_operations).to be_nil
      end
    end
  end
end
