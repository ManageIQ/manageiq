require "spec_helper"

describe "StatusManagement" do
  before(:each) do
    @guid, @miq_server, @zone = EvmSpecHelper.create_guid_miq_server_zone
  end

  #for now, just making sure there are no syntax errors
  it ".log_status" do
    MiqServer.should_receive(:log_system_status).once
    MiqServer.log_status
  end
end
