describe "ems_infra/show.html.haml" do
  let(:zone) { FactoryGirl.create(:zone) }
  let(:ems_infra) { FactoryGirl.create(:ems_vmware, :hostname => '1.1.1.1', :zone => zone) }
  let(:action) { 'index' }

  before do
    allow(MiqServer).to receive(:my_zone).and_return("default")
    creds = {}
    creds[:amqp] = {:userid => "amqp_user", :password => "amqp_password"}
    ems_infra.update_authentication(creds, :save => true)
    ems_infra.reload
    assign(:ems, ems_infra)
    assign(:record, ems_infra)
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
