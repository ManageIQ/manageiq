require "spec_helper"

describe "InspectMe Automate Method" do
  before(:each) do
    @guid = MiqUUID.new_guid
    MiqServer.stub(:my_guid).and_return(@guid)
    @zone       = FactoryGirl.create(:zone)
    @miq_server = FactoryGirl.create(:miq_server, :guid => @guid, :zone => @zone)
  end

  def run_automate_method
    attrs = []
    attrs << "MiqServer::miq_server=#{@miq_server.id}"

    MiqAeEngine.instantiate("/System/Request/Call_Instance_With_Message?" \
                            "namespace=System&class=Request" \
                            "&instance=InspectMe&" \
                            "#{attrs.join('&')}")
  end

  context "InspectMe" do
    it "with miq_server" do
      run_automate_method
    end
  end
end
