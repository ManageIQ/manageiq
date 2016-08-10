require 'routing/shared_examples'

describe 'routes for ServiceController' do
  let(:controller_name) { 'service' }

  it_behaves_like "A controller that has dialog runner routes"
  it_behaves_like 'A controller that has download_data routes'

  describe "#button" do
    it "routes with POST" do
      expect(post("/service/button")).to route_to("service#button")
    end
  end

  describe '#explorer' do
    it 'routes with GET' do
      expect(get("/service/explorer")).to route_to("service#explorer")
    end

    it 'routes with POST' do
      expect(post("/service/explorer")).to route_to("service#explorer")
    end
  end

  describe "#ownership_field_changed" do
    it "routes with POST" do
      expect(post("/service/ownership_field_changed"))
        .to route_to("service#ownership_field_changed")
    end
  end

  describe "#ownership_update" do
    it "routes with POST" do
      expect(post("/service/ownership_update")).to route_to("service#ownership_update")
    end
  end

  describe "#reload" do
    it "routes with POST" do
      expect(post("/service/reload")).to route_to("service#reload")
    end
  end

  describe "#retire" do
    it "routes with POST" do
      expect(post("/service/retire")).to route_to("service#retire")
    end
  end

  describe "#retirement_info" do
    it "routes with GET" do
      expect(get("/service/retirement_info")).to route_to("service#retirement_info")
    end
  end

  describe "#edit" do
    it "routes with GET" do
      expect(get("/service/123/edit")).to route_to("service#edit", :id => "123")
    end
  end

  describe "#service_tag" do
    it "routes with POST" do
      expect(post("/service/service_tag")).to route_to("service#service_tag")
    end
  end

  describe "#show" do
    it "routes with GET" do
      expect(get("/#{controller_name}/123")).to route_to("#{controller_name}#show", :id => "123")
    end
  end

  describe "#tag_edit_form_field_changed" do
    it "routes with POST" do
      expect(post("/service/tag_edit_form_field_changed"))
        .to route_to("service#tag_edit_form_field_changed")
    end
  end

  describe '#tree_autoload_dynatree' do
    it 'routes with POST' do
      expect(
        post("/#{controller_name}/tree_autoload_dynatree")
      ).to route_to("#{controller_name}#tree_autoload_dynatree")
    end
  end

  describe "#tree_select" do
    it "routes with POST" do
      expect(post("/service/tree_select")).to route_to("service#tree_select")
    end
  end

  describe "#x_button" do
    it "routes with POST" do
      expect(post("/service/x_button")).to route_to("service#x_button")
    end
  end

  describe "#x_history" do
    it "routes with POST" do
      expect(post("/service/x_history")).to route_to("service#x_history")
    end
  end

  describe "#x_show" do
    it "routes with POST" do
      expect(post("/service/x_show")).to route_to("service#x_show")
    end
  end
end
