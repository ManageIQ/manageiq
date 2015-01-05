require "spec_helper"
require "routing/shared_examples"

describe EmsCloudController do
  let(:controller_name) { "ems_cloud" }

  it_behaves_like "A controller that has advanced search routes"
  it_behaves_like "A controller that has column width routes"
  it_behaves_like "A controller that has compare routes"
  it_behaves_like "A controller that has CRUD routes"
  it_behaves_like "A controller that has discovery routes"
  it_behaves_like "A controller that has download_data routes"
  it_behaves_like "A controller that has policy protect routes"
  it_behaves_like "A controller that has tagging routes"
  it_behaves_like "A controller that has timeline routes"

  %w(
    edit
    index
    new
    show
    show_list
  ).each do |task|
    describe "##{task}" do
      it 'routes with GET' do
        expect(get("/#{controller_name}/#{task}")).to route_to("#{controller_name}##{task}")
      end
    end
  end

  %w(
    button
    create
    dynamic_list_refresh
    dynamic_radio_button_refresh
    form_field_changed
    listnav_search_selected
    save_default_search
    show
    show_list
    update
  ).each do |task|
    describe "##{task}" do
      it 'routes with POST' do
        expect(post("/#{controller_name}/#{task}")).to route_to("#{controller_name}##{task}")
      end
    end
  end
end
