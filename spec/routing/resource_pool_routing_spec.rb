require "spec_helper"
require "routing/shared_examples"

describe "routes for AvailabilityZoneController" do
  let(:controller_name) { "resource_pool" }

  it_behaves_like "A controller that has advanced search routes"
  it_behaves_like "A controller that has column width routes"
  it_behaves_like "A controller that has compare routes"
  it_behaves_like "A controller that has download_data routes"
  it_behaves_like "A controller that has show list routes"
  it_behaves_like "A controller that has tagging routes"
  it_behaves_like "A controller that has policy protect routes"

  %w(
    index
    show
  ).each do |task|
    describe "##{task}" do
      it 'routes with GET' do
        expect(get("/#{controller_name}/#{task}")).to route_to("#{controller_name}##{task}")
      end
    end
  end

  %w(
    button
    listnav_search_selected
    save_default_search
    show
  ).each do |task|
    describe "##{task}" do
      it 'routes with POST' do
        expect(post("/#{controller_name}/#{task}")).to route_to("#{controller_name}##{task}")
      end
    end
  end
end
