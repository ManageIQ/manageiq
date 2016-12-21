describe GenericObjectController do
  include_context "valid session"

  before do
    stub_user(:features => :all)
  end

  describe "#create" do
    let(:params) { {:name => "name", :description => "description"} }

    it "creates a new generic object definition" do
      expect(GenericObjectDefinition.first).to be_nil
      post :create, params
      expect(GenericObjectDefinition.first).to_not be_nil
    end

    it "renders a json message on success" do
      post :create, params
      expect(response.body).to eq({
        :message => "Generic Object Definition created successfully"
      }.to_json)
    end
  end

  describe "#save" do
    let(:params) { {:id => generic_object_definition.id, :name => "new name", :description => "new description"} }
    let(:generic_object_definition) { GenericObjectDefinition.create!(:name => "name", :description => "description") }

    before do
      post :save, params
      generic_object_definition.reload
    end

    it "adjusts the name" do
      expect(generic_object_definition.name).to eq("new name")
    end

    it "adjusts the description" do
      expect(generic_object_definition.description).to eq("new description")
    end

    it "renders a json message on success" do
      expect(response.body).to eq({
        :message => "Generic Object Definition saved successfully"
      }.to_json)
    end
  end

  describe "#delete" do
    let(:params) { {:id => generic_object_definition.id} }
    let(:generic_object_definition) { GenericObjectDefinition.create!(:name => "name", :description => "description") }

    before do
      post :delete, params
    end

    it "deletes the generic object" do
      expect(GenericObjectDefinition.count).to eq(0)
    end

    it "renders a json message" do
      expect(response.body).to eq({
        :message => "Generic Object Definition deleted"
      }.to_json)
    end
  end

  describe "#explorer" do
    let(:tree_builder_generic_object) { double("TreeBuilderGenericObject") }

    before do
      bypass_rescue
      allow(TreeBuilderGenericObject).to receive(:new).and_return(tree_builder_generic_object)
      allow(tree_builder_generic_object).to receive(:nodes).and_return("nodes")

      get :explorer
    end

    it "sets up the layout variable" do
      expect(assigns[:layout]).to eq("generic_object")
    end

    it "sets up the accords variable" do
      expect(assigns[:accords]).to eq(
        [{
          :name      => "generic_object_definition_accordion",
          :title     => "Generic Objects",
          :container => "generic_object_definition_accordion_accord"
        }]
      )
    end

    it "sets up the trees variable" do
      expect(assigns[:trees]).to eq("nodes")
    end

    it "sets the explorer variable to true" do
      expect(assigns[:explorer]).to eq(true)
    end

    it "renders the application layout" do
      expect(response).to render_template(:layout => "application")
    end
  end

  describe "#all_object_data" do
    before do
      @generic_object_definition = GenericObjectDefinition.create!(:name => "name", :description => "description")
    end

    it "returns all generic object definition ids, names, and descriptions in a json format" do
      get :all_object_data
      expect(response.body).to eq([{
        :id          => @generic_object_definition.id,
        :name        => "name",
        :description => "description"
      }].to_json)
    end
  end

  describe "#object_data" do
    let(:params) { {:id => @generic_object_definition.id} }

    before do
      @generic_object_definition = GenericObjectDefinition.create!(:name => "name", :description => "description")
    end

    it "returns the name and description of the selected item in a json format" do
      get :object_data, params
      expect(response.body).to eq({
        :id          => @generic_object_definition.id,
        :name        => "name",
        :description => "description"
      }.to_json)
    end
  end

  describe "#tree_data" do
    let(:tree_builder_generic_object) { double("TreeBuilderGenericObject") }

    before do
      allow(TreeBuilderGenericObject).to receive(:new).and_return(tree_builder_generic_object)
      allow(tree_builder_generic_object).to receive(:nodes).and_return("the tree data")
    end

    it "returns the tree data" do
      get :tree_data
      expect(response.body).to eq({:tree_data => "the tree data"}.to_json)
    end
  end
end
