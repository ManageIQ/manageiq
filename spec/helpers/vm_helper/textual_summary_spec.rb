require "spec_helper"

describe VmHelper do
  context "::TextualSummary" do
    before(:each) do
      guid, @server, zone = EvmSpecHelper.create_guid_miq_server_zone
      @record = FactoryGirl.create(:vm_vmware, :miq_server => @server)
    end

    it "#textual_server" do
      expect(helper.textual_server).to eq("#{@server.name} [#{@server.id}]")
    end
  end
end
