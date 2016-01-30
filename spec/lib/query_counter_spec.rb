describe QueryCounter do
  it "counts named queries" do
    expect(QueryCounter.count { Host.first }).to eq(1)
  end

  it "counts no named queries" do
    expect(QueryCounter.count { Host.where(:id => 1).pluck(:id) }).to eq(1)
  end

  it "doesnt count transactions" do
    expect(QueryCounter.count { Host.transaction { Host.first ; Host.count }}).to eq(2)
  end
end
