RSpec.describe Spec::Support::QueryCounter do
  it "counts named queries" do
    expect(Spec::Support::QueryCounter.count { Host.first }).to eq(1)
  end

  it "counts no named queries" do
    expect(Spec::Support::QueryCounter.count { Host.where(:id => 1).pluck(:id) }).to eq(1)
  end

  it "doesnt count transactions" do
    expect(
      Spec::Support::QueryCounter.count do
        Host.transaction do
          Host.first
          Host.count
        end
      end
    ).to eq(2)
  end
end
