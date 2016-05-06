describe "ems_cluster/show.html.haml" do
  let(:ems_cluster) { FactoryGirl.create(:ems_cluster_openstack) }
  let(:action) { 'index' }

  before do
    allow(MiqServer).to receive(:my_zone).and_return("default")
    creds = {}
    creds[:amqp] = {:userid => "amqp_user", :password => "amqp_password"}
    assign(:ems, ems_cluster)
    assign(:record, ems_cluster)
    assign(:showtype, showtype)
  end

  context 'when showtype is drift' do
    let(:showtype) { 'drift' }

    it 'should render the compare partial' do
      render
      expect(response).to render_template(:partial => 'layouts/_compare')
    end
  end
end
