describe "availability_zone/show.html.haml" do
  shared_examples_for "miq_before_onload JS is needed" do
    it "renders proper JS" do
      js_string = "var miq_after_onload = \"miqAsyncAjax('/availability_zone/#{action}/#{availability_zone.id}');\""
      render
      expect(rendered).to include(js_string)
    end
  end

  let(:availability_zone) { double("AvailabilityZone", :name => 'My AZ', :id => 1) }
  let(:action) { 'index' }

  before do
    assign(:record, availability_zone)
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

  context "when showtype is 'timeline'" do
    let(:showtype) { "timeline" }

    before do
      assign(:tl_options, ApplicationController::Timelines::Options.new)
    end

    it_behaves_like "miq_before_onload JS is needed"
  end
end
