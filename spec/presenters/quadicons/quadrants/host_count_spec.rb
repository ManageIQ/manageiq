describe Quadicons::Quadrants::HostCount, :type => :helper do
  let(:record) do
    FactoryGirl.create(
      :storage,
      :total_space => 1000,
      :free_space  => 250
    )
  end

  let(:kontext) { Quadicons::Context.new(helper) }
  subject(:quadrant) { Quadicons::Quadrants::HostCount.new(record, kontext) }

  it 'shows the host count for the record' do
    allow(record).to receive(:v_total_hosts) { 314 }
    expect(quadrant.render).to include("314")
  end
end
