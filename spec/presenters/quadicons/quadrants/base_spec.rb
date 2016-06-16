describe Quadicons::Quadrants::Base, :type => :helper do
  subject(:quadrant) { Quadicons::Quadrants::Base.new(record, helper) }
  let(:record) { FactoryGirl.build(:vm_vmware) }

  it 'returns unfiltered html' do
    expect(quadrant.render).not_to match(/&lt;/)
  end
end
