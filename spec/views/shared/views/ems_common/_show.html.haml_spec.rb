describe "shared/views/ems_common/show" do
  let(:zone) { FactoryGirl.create(:zone) }
  let(:ems_cloud) { FactoryGirl.create(:ems_openstack, :hostname => '1.1.1.1', :zone => zone) }
  let(:action) { 'index' }

  before do
    view.extend EmsCloudHelper::TextualSummary
    allow(MiqServer).to receive(:my_zone).and_return("default")
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
      expect(rendered).not_to include('&lt;Unknown&gt; Credentials')
    end

    it "should show 'AMQP Credentials'" do
      render
      expect(rendered).to include('AMQP Credentials')
    end
  end
end
