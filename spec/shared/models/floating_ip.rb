shared_examples :floating_ip do |provider_name|
  it ".available" do
    vm = FactoryGirl.create("vm_#{provider_name}")
    _ip1 = FactoryGirl.create("floating_ip_#{provider_name}", :vm => vm)
    ip2 = FactoryGirl.create("floating_ip_#{provider_name}")

    expect(described_class.available).to eq([ip2])
  end
end
