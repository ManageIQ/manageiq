describe "show_performance.html.haml" do
  shared_examples_for "miq_before_onload JS is needed" do
    it "renders proper JS" do
      js_string = "ManageIQ.afterOnload = \"miqAsyncAjax('/host/#{action}/#{host.id}');\""
      render
      expect(rendered).to include(js_string)
    end
  end

  let(:host) { FactoryGirl.create(:host_vmware, :name => 'My Host') }
  let(:action) { 'index' }

  before do
    assign(:record, host)
    assign(:ajax_action, action)
    assign(:showtype, showtype)
  end

  context "when showtype is 'performance'" do
    let(:showtype) { "performance" }

    before do
      assign(:perf_options, :chart_type => :performance)
    end

    it_behaves_like "miq_before_onload JS is needed"
  end
end
