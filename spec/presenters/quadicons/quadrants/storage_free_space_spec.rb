describe Quadicons::Quadrants::StorageFreeSpace, :type => :helper do
  let(:kontext) { Quadicons::Context.new(helper) }
  subject(:quadrant) { Quadicons::Quadrants::StorageFreeSpace.new(record, kontext) }

  let(:record) do
    FactoryGirl.create(
      :storage,
      :total_space => 1000
    )
  end

  context "when free space percent of total is 100" do
    before do
      record.free_space = 1000
    end

    it 'shows a full pie' do
      expect(quadrant.render).to match(/20/)
    end
  end

  context "when free space percent is not 100" do
    before do
      record.free_space = 250
    end

    it 'shows free space' do
      expect(quadrant.render).to match(/5/)
    end
  end
end
