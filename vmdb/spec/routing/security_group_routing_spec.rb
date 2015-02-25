require "spec_helper"
require "routing/shared_examples"

describe "routing for SecurityGroupController" do
  let(:controller_name) { "security_group" }

  it_behaves_like "A controller that has advanced search routes"
  it_behaves_like "A controller that has column width routes"
  it_behaves_like "A controller that has compare routes"
  it_behaves_like "A controller that has tagging routes"

  %w(
    download_data
    index
    show
    show_list
    tagging_edit
  ).each do |task|
    describe "##{task}" do
      it 'routes with GET' do
        expect(get("/#{controller_name}/#{task}")).to route_to("#{controller_name}##{task}")
      end
    end
  end

  %w(
    button
    quick_search
    panel_control
    save_col_widths
    show
    show_list
    tag_edit_form_field_changed
    tagging_edit
  ).each do |task|
    describe "##{task}" do
      it 'routes with POST' do
        expect(post("/#{controller_name}/#{task}")).to route_to("#{controller_name}##{task}")
      end
    end
  end
end
