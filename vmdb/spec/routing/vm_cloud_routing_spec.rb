require 'spec_helper'
require 'routing/shared_examples'

describe 'routes for VmCloud' do
  let(:controller_name) { 'vm_cloud' }

  it_behaves_like 'A controller that has advanced search routes'
  it_behaves_like 'A controller that has column width routes'
  it_behaves_like 'A controller that has compare routes'
  it_behaves_like 'A controller that has download_data routes'
  it_behaves_like 'A controller that has explorer routes'
  it_behaves_like 'A controller that has performance routes'
  it_behaves_like 'A controller that has policy protect routes'
  it_behaves_like 'A controller that has tagging routes'
  it_behaves_like 'A controller that has timeline routes'
  it_behaves_like 'A controller that has vm_common routes'

  describe '#dialog_form_button_pressed' do
    it 'routes with POST' do
      expect(
        post("/#{controller_name}/dialog_form_button_pressed")
      ).to route_to("#{controller_name}#dialog_form_button_pressed")
    end
  end

  describe '#dialog_field_changed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/dialog_field_changed")).to route_to("#{controller_name}#dialog_field_changed")
    end
  end

  describe "#dynamic_list_refresh" do
    it "routes with POST" do
      expect(post("/#{controller_name}/dynamic_list_refresh")).to route_to("#{controller_name}#dynamic_list_refresh")
    end
  end

  describe '#pre_prov' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/pre_prov")).to route_to("#{controller_name}#pre_prov")
    end
  end

  describe '#pre_prov_continue' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/pre_prov_continue")).to route_to("#{controller_name}#pre_prov_continue")
    end
  end

  describe '#vm_pre_prov' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/vm_pre_prov")).to route_to("#{controller_name}#vm_pre_prov")
    end
  end
end
