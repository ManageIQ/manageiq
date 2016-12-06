describe Quadicons::Quadrants::GuestCount, :type => :helper do
  let(:record) do
    FactoryGirl.create(
      :storage,
      :total_space => 1000,
      :free_space  => 250
    )
  end

  let(:kontext) { Quadicons::Context.new(helper) }
  subject(:quadrant) { Quadicons::Quadrants::GuestCount.new(record, kontext) }

  it 'shows the vm count for the record' do
    allow(record).to receive(:v_total_vms) { 42 }
    expect(quadrant.render).to include("42")
  end
end
