shared_examples :floating_ip do |provider_name|
  it ".available" do
    vm = FactoryBot.create("vm_#{provider_name}")
    _ip1 = FactoryBot.create("floating_ip_#{provider_name}", :vm => vm)
    ip2 = FactoryBot.create("floating_ip_#{provider_name}")

    expect(described_class.available).to eq([ip2])
  end
end
