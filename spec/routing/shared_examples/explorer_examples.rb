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

  describe '#tree_autoload_dynatree' do
    it 'routes with POST' do
      expect(
        post("/#{controller_name}/tree_autoload_dynatree")
      ).to route_to("#{controller_name}#tree_autoload_dynatree")
    end
  end

  describe '#tree_select' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/tree_select")).to route_to("#{controller_name}#tree_select")
    end
  end

  describe '#x_settings_changed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/x_settings_changed")).to route_to("#{controller_name}#x_settings_changed")
    end
  end
end
