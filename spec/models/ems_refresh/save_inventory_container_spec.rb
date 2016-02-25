require "spec_helper"

describe EmsRefresh::SaveInventoryContainer do
  let(:dummy) { (Class.new { include EmsRefresh::SaveInventoryContainer }).new }

  context 'with a simple descriptor' do
    before(:each) do
      stub_const("#{described_class}::DESCRIPTOR",
                 :pizza   => {
                   :links    => [:box],
                   :children => [:toppings]
                 },
                 :topping => {})
      stub_const("#{described_class}::ALWAYS_IGNORED", [])
    end

    it 'does not define unneeded methods' do
      expect { dummy.make_pizza }.to raise_error(NoMethodError)
    end

    it 'does not define unneeded save_x_inventory methods' do
      expect { dummy.save_falafel_inventory(:apples, :ems_ref, [], [], nil) }.to raise_error(
        NoMethodError,
        /undefined method `save_falafel_inventory'/
      )
    end

    it 'calls save_inventory_single when given a single entity' do
      parent = Object.new
      hashes = [{}]
      expect(dummy).to receive(:save_inventory_single).with('topping', parent, hashes, [], [])
      dummy.save_topping_inventory(parent, hashes)
    end

    it 'calls save_inventory_multi when given a multiple entity' do
      parent = double
      new_hashes = [:a]
      old_hashes = []
      expect(parent).to receive(:toppings).exactly(3).times { old_hashes }
      expect(dummy).to receive(:save_inventory_multi).with(old_hashes, new_hashes, old_hashes.dup, [:ems_ref], [], [])
      expect(dummy).to receive(:store_ids_for_new_records)
      dummy.save_toppings_inventory(parent, new_hashes)
    end
  end
end
