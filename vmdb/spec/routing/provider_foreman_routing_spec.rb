require 'spec_helper'
require 'routing/shared_examples'

describe 'routes for ProviderForeman' do
  let(:controller_name) { 'provider_foreman' }

  it_behaves_like 'A controller that has advanced search routes'
  it_behaves_like 'A controller that has download_data routes'

  %w(
    download_data
    explorer
    provider_foreman_form_fields
    show
  ).each do |task|
    describe "##{task}" do
      it 'routes with GET' do
        expect(get("/#{controller_name}/#{task}")).to route_to("#{controller_name}##{task}")
      end
    end
  end

  %w(
    accordion_select
    authentication_validate
    button
    delete
    edit
    explorer
    exp_button
    exp_changed
    exp_token_pressed
    form_field_changed
    new
    panel_control
    quick_search
    refresh
    reload
    save_col_widths
    show
    show_list
    tree_autoload_dynatree
    tree_select
    users
    wait_for_task
    x_button
    x_history
    x_search_by_name
    x_show
  ).each do |task|
    describe "##{task}" do
      it 'routes with POST' do
        expect(post("/#{controller_name}/#{task}")).to route_to("#{controller_name}##{task}")
      end
    end
  end
end
