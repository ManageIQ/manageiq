require "spec_helper"

describe VmHelper do
  context "::TextualSummary" do
    before(:each) do
      guid, @server, zone = EvmSpecHelper.create_guid_miq_server_zone
      @record = FactoryGirl.create(:vm_vmware, :miq_server => @server)
    end

    it "#textual_server" do
      helper.textual_server.should == {:label => "Server", :value => "#{@server.name} [#{@server.id}]"}
    end
  end
end
