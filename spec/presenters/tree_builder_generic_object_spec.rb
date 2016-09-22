describe TreeBuilderGenericObject do
  let(:tree_builder) { described_class.new }

  describe "#nodes" do
    let(:generic_object_definition) { double("GenericObjectDefinition", :id => 123, :name => "name") }

    before do
      allow(GenericObjectDefinition).to receive(:all).and_return([generic_object_definition])
    end

    it "returns a json tree with a root node" do
      result = JSON.parse(tree_builder.nodes)
      expect(result.first).to include(
        "text" => "Generic Objects",
        "href" => "#generic-objects-root",
        "tags" => ["4"]
      )
    end

    it "returns the children of the root node" do
      result = JSON.parse(tree_builder.nodes)
      expect(result.first["nodes"]).to include(
        "text" => "name",
        "href" => "#name",
        "icon" => "fa fa-file-o",
        "tags" => ["2"],
        "id"   => 123
      )
    end
  end
end
