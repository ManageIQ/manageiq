describe VmHelper::TextualSummary do
  it "#textual_server" do
    server  = FactoryGirl.build(:miq_server, :id => 99999)
    @record = FactoryGirl.build(:vm_vmware, :miq_server => server)
    expect(helper.textual_server).to eq("#{server.name} [#{server.id}]")
  end
end
