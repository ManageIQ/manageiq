describe Quadicons::Quadrants::StorageUsedSpace, :type => :helper do
  let(:kontext) { Quadicons::Context.new(helper) }
  subject(:quadrant) { Quadicons::Quadrants::StorageUsedSpace.new(record, kontext) }

  let(:record) do
    FactoryGirl.create(
      :storage,
      :total_space => 1000,
      :free_space => 250
    )
  end

  it 'shows used space' do
    expect(quadrant.render).to match(/8/)
  end
end
