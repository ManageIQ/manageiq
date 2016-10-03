require "routing/shared_examples"

describe EmsStorageController do
  let(:controller_name) { "ems_storage" }

  it_behaves_like "A controller that has compare routes"
  it_behaves_like "A controller that has dialog runner routes"
  it_behaves_like "A controller that has download_data routes"
  it_behaves_like "A controller that has policy protect routes"
  it_behaves_like "A controller that has tagging routes"
  it_behaves_like "A controller that has timeline routes"

  %w(
    dialog_load
    ems_storage_form_fields
    new
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

  describe "#index" do
    it "routes with GET" do
      expect(get("/#{controller_name}")).to route_to("#{controller_name}#index")
    end
  end

  describe "#update" do
    it "routes with POST" do
      expect(post("/#{controller_name}/update/123")).to route_to("#{controller_name}#update", :id => "123")
    end
  end
end
