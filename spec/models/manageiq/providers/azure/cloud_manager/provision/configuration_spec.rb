describe ManageIQ::Providers::Azure::CloudManager::Provision::Configuration do
  it "#userdata_payload is Base64 encoded" do
    template  = FactoryGirl.build(:customization_template, :script => "#cloud-init")
    provision = ManageIQ::Providers::Azure::CloudManager::Provision.new
    allow(provision).to receive(:customization_template).and_return(template)
    allow(provision).to receive(:post_install_callback_url).and_return("")
    expect(Base64.decode64(provision.userdata_payload)).to eq(template.script)
  end
end
