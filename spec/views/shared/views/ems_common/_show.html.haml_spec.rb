describe "shared/views/ems_common/show" do
  TestSetup = Struct.new(:ems_type, :helper)
  [
    TestSetup.new(:ems_openstack, EmsCloudHelper::TextualSummary),
    TestSetup.new(:ems_vmware,    EmsInfraHelper::TextualSummary),
  ].each do |setup|
    let(:zone) { FactoryGirl.create(:zone) }
    let(:ems) { FactoryGirl.create(setup.ems_type, :hostname => '1.1.1.1', :zone => zone) }
    let(:action) { 'index' }

    before do
      view.extend setup.helper
      allow(MiqServer).to receive(:my_zone).and_return("default")
      creds = {}
      creds[:amqp] = {:userid => "amqp_user", :password => "amqp_password"}
      ems.update_authentication(creds, :save => true)
      ems.reload
      assign(:ems, ems)
      assign(:record, ems)
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
end
