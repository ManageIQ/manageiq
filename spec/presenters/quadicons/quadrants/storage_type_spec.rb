describe Quadicons::Quadrants::StorageType, :type => :helper do
  let(:record) do
    FactoryGirl.create(
      :storage,
      :total_space => 1000,
      :free_space  => 250
    )
  end

  let(:kontext) { Quadicons::Context.new(helper) }
  subject(:quadrant) { Quadicons::Quadrants::StorageType.new(record, kontext) }

  context "when storage type is known" do
    before do
      record.store_type = "VMFS"
    end

    it 'shows the storage_type' do
      expect(quadrant.render).to include("storagetype-vmfs")
    end
  end

  context "when storage type is unknown" do
    it 'shows the storage_type' do
      expect(quadrant.render).to include("storagetype-unknown")
    end
  end
end
