shared_examples_for "A controller that has explorer routes" do
  describe '#accordion_select' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/accordion_select")).to route_to("#{controller_name}#accordion_select")
    end
  end

  describe '#explorer' do
    it 'routes with GET' do
      expect(get("/#{controller_name}/explorer")).to route_to("#{controller_name}#explorer")
    end
  end

  describe '#tree_autoload' do
    it 'routes with POST' do
      expect(
        post("/#{controller_name}/tree_autoload")
      ).to route_to("#{controller_name}#tree_autoload")
    end
  end

  describe '#tree_select' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/tree_select")).to route_to("#{controller_name}#tree_select")
    end
  end
end
