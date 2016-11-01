describe OpsController do
  include_context "valid session"

  describe '#label_tag_mapping_edit' do
    it "initilizes form for new mapping" do
      post :label_tag_mapping_edit
      expect(assigns(:edit)[:new]).to include(:entity => nil, :label_name => nil, :category => nil)
    end

    def use_form_to_create_mapping
      post :label_tag_mapping_edit
      post :label_tag_mapping_field_changed, :id => 'new', :entity => 'ContainerProject'
      post :label_tag_mapping_field_changed, :id => 'new', :label_name => 'my-label'
      post :label_tag_mapping_field_changed, :id => 'new', :category => 'My Cat'
      post :label_tag_mapping_edit, :button => 'add'
    end

    it "creates new mapping on save" do
      use_form_to_create_mapping
      mapping = ContainerLabelTagMapping.last
      expect(mapping.labeled_resource_type).to eq('ContainerProject')
      expect(mapping.label_name).to eq('my-label')
      expect(mapping.label_value).to be nil
      expect(mapping.tag.classification.category?).to be true
      expect(mapping.tag.classification.description).to eq('My Cat')
    end

    it "can edit existing mapping" do
      use_form_to_create_mapping
      mapping = ContainerLabelTagMapping.last

      post :label_tag_mapping_edit, :id => mapping.id.to_s
      expect(assigns(:edit)[:new]).to include(:entity     => 'ContainerProject',
                                              :label_name => 'my-label',
                                              :category   => 'My Cat')

      post :label_tag_mapping_field_changed, :id => mapping.id.to_s, :category => 'Edited Cat'
      expect(assigns(:edit)[:new]).to include(:entity     => 'ContainerProject',
                                              :label_name => 'my-label',
                                              :category   => 'Edited Cat')

      post :label_tag_mapping_edit, :id => mapping.id.to_s, :button => 'reset'
      expect(assigns(:edit)[:new]).to include(:entity     => 'ContainerProject',
                                              :label_name => 'my-label',
                                              :category   => 'My Cat')

      post :label_tag_mapping_field_changed, :id => mapping.id.to_s, :category => 'Edited Again Cat'
      expect(assigns(:edit)[:new]).to include(:entity     => 'ContainerProject',
                                              :label_name => 'my-label',
                                              :category   => 'Edited Again Cat')

      # Kludge: @flash_array contains "was added" from previous actions since
      # we're reusing one controller in the test.
      controller.instance_variable_set :@flash_array, nil
      post :label_tag_mapping_edit, :id => mapping.id.to_s, :button => 'save'
      expect(mapping.tag.classification.description).to eq('Edited Again Cat')
    end
  end
end
