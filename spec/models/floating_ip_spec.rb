describe FloatingIp do
  it ".available" do
    vm = FactoryGirl.create(:vm_amazon)
    ip1 = FactoryGirl.create(:floating_ip_amazon, :vm => vm)
    ip2 = FactoryGirl.create(:floating_ip_amazon)

    expect(described_class.available).to eq([ip2])
  end
end
