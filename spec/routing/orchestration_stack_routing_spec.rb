require "routing/shared_examples"

describe OrchestrationStackController do
  let(:controller_name) { "orchestration_stack" }

  it_behaves_like "A controller that has advanced search routes"
  it_behaves_like "A controller that has download_data routes"
  it_behaves_like "A controller that has tagging routes"

  %w(
    cloud_networks
    download_data
    index
    outputs
    parameters
    resources
    show
    show_list
    tagging_edit
    protect
  ).each do |task|
    describe "##{task}" do
      it 'routes with GET' do
        expect(get("/#{controller_name}/#{task}")).to route_to("#{controller_name}##{task}")
      end
    end
  end

  %w(
    button
    cloud_networks
    outputs
    listnav_search_selected
    parameters
    quick_search
    resources
    save_default_search
    sections_field_changed
    show
    show_list
    tagging_edit
    tag_edit_form_field_changed
    protect
  ).each do |task|
    describe "##{task}" do
      it 'routes with POST' do
        expect(post("/#{controller_name}/#{task}")).to route_to("#{controller_name}##{task}")
      end
    end
  end
end
