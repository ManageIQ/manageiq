describe Quadicons::Quadrants::SnapshotCount, :type => :helper do
  let(:record) { FactoryGirl.build(:vm_vmware) }
  let(:kontext) { Quadicons::Context.new(helper) }
  subject(:quadrant) { Quadicons::Quadrants::SnapshotCount.new(record, kontext) }

  it 'renders a quadrant with a count' do
    allow(record).to receive(:v_total_snapshots).and_return(42)

    expect(quadrant.render).to match(/quadrant-snapshot/)
    expect(quadrant.render).to match(/quadrant-value/)
    expect(quadrant.render).to include("42")
  end
end
