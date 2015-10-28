require "spec_helper"

describe "ems_cloud/show.html.haml" do
  let(:zone) { FactoryGirl.create(:zone) }
  let(:ems_cloud) { FactoryGirl.create(:ems_openstack, :hostname => '1.1.1.1', :zone => zone) }
  let(:action) { 'index' }

  before do
    MiqServer.stub(:my_zone).and_return("default")
    creds = {}
    creds[:amqp] = {:userid => "amqp_user", :password => "amqp_password"}
    ems_cloud.update_authentication(creds, :save => true)
    ems_cloud.reload
    assign(:ems, ems_cloud)
    assign(:record, ems_cloud)
    assign(:showtype, showtype)
  end

  context "when showtype is 'main'" do
    let(:showtype) { "main" }
    it "should not show '<Unknown> Credentials'" do
      render
      rendered.should_not include('&lt;Unknown&gt; Credentials')
    end

    it "should show 'AMQP Credentials'" do
      render
      rendered.should include('AMQP Credentials')
    end
  end
end
