describe "#number_of" do
  it "caches the results" do
    h = FactoryGirl.create(:host)
    FactoryGirl.create_list(:vm, 2, :host => h)

    expect(h).to receive(:vms).once.and_call_original

    expect(h.number_of(:vms)).to eq(2)
    expect(h.number_of(:vms)).to eq(2)
  end

  it "doesn't load a whole relation" do
    h = FactoryGirl.create(:host)
    FactoryGirl.create_list(:vm, 2, :host => h)

    expect(h.number_of(:vms)).to eq(2)
    expect(h.vms).not_to be_loaded
  end

  it "uses the relation if it is available" do
    h = FactoryGirl.create(:host)
    FactoryGirl.create_list(:vm, 2, :host => h)

    h.vms.load
    expect do
      expect(h.number_of(:vms)).to eq(2)
    end.to match_query_limit_of(0)
  end
end
