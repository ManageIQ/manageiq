shared_examples_for "A controller that has CRUD routes" do
  describe "#index" do
    it "routes with GET" do
      expect(get("/#{controller_name}")).to route_to("#{controller_name}#index")
    end
  end

  describe "#create" do
    it "routes with POST" do
      expect(post("/#{controller_name}/create")).to route_to("#{controller_name}#create")
    end
  end

  describe "#edit" do
    it "routes with GET" do
      expect(get("/#{controller_name}/edit/123")).to route_to("#{controller_name}#edit", :id => "123")
    end
  end

  describe "#show" do
    it "routes with GET" do
      expect(get("/#{controller_name}/show/123")).to route_to("#{controller_name}#show", :id => "123")
    end
  end

  describe "#update" do
    it "routes with POST" do
      expect(post("/#{controller_name}/update/123")).to route_to("#{controller_name}#update", :id => "123")
    end
  end
end
