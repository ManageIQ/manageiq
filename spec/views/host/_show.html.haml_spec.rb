require "spec_helper"
include ApplicationHelper

describe "host/show.html.haml" do
  shared_examples_for "miq_before_onload JS is needed" do
    it "renders proper JS" do
      js_string = "var miq_after_onload = \"miqAsyncAjax('/host/#{action}/#{host.id}');\""
      render
      rendered.should include(js_string)
    end
  end

  # TODO: For speed, replace next line with active_record_instance_double when available
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

  context "when showtype is 'timeline'" do
    let(:showtype) { "timeline" }

    before do
      assign(:tl_options, {})
    end

    it_behaves_like "miq_before_onload JS is needed"
  end

  context "when showtype is 'details'" do
    let(:showtype) { "details" }
    let(:display) { "main" }

    it "should render gtl view" do
      assign(:lastaction, "host_services")
      assign(:view, OpenStruct.new(:table => OpenStruct.new(:data => [])))
      render
      expect(view).to render_template(partial: 'layouts/gtl', :locals => {:action_url => 'host_services'})
    end
  end
end
