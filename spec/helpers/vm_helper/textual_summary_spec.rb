require "spec_helper"

describe VmHelper::TextualSummary do
  it "#textual_server" do
    server  = FactoryGirl.create(:miq_server)
    @record = FactoryGirl.create(:vm_vmware, :miq_server => server)
    expect(helper.textual_server).to eq("#{server.name} [#{server.id}]")
  end
end
