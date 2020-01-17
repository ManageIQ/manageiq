RSpec.describe ManageIQ::Providers::CloudManager::Provision::Configuration do
  it "#userdata_payload is clear text" do
    template  = FactoryBot.build(:customization_template, :script => "#cloud-init")
    provision = ManageIQ::Providers::CloudManager::Provision.new
    allow(provision).to receive(:customization_template).and_return(template)
    allow(provision).to receive(:post_install_callback_url).and_return("")
    expect(provision.userdata_payload).to eq(template.script)
  end
end
