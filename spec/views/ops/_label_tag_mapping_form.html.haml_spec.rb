describe 'ops/_label_tag_mapping_form.html.haml' do
  before do
    assign(:sb, :active_tab => 'settings_label_tag_mapping')
  end

  context 'add new mapping' do
    before(:each) do
      @lt_map = nil
      @edit = {:id  => nil,
               :new => {:options    => [["<All>", nil]],
                        :entity     => nil,
                        :label_name => nil,
                        :category   => nil}}
      render :partial => "ops/label_tag_mapping_form"
    end

    it 'renders the entity select box' do
      expect(render).to have_selector('select#entity')
    end

    it 'renders the label name text box' do
      expect(render).to have_selector('input#label_name')
    end

    it 'renders the category name text box' do
      expect(render).to have_selector('input#category')
    end

    it 'entity should be enabled when adding a new mapping' do
      expect(response.body).to include('<select name="entity" id="entity" class="selectpicker">')
    end

    it 'label should be enabled when adding a new mapping' do
      expect(response.body).to include('<input type="text" name="label_name" id="label_name" maxlength="25" class="form-control" data-miq_observe')
    end

    it 'category should be enabled when adding a new mapping' do
      expect(response.body).to include('<input type="text" name="category" id="category" maxlength="50" class="form-control" data-miq_observe')
    end
  end

  context 'edit existing mapping' do
    before(:each) do
      @lt_map = FactoryGirl.create(:container_label_tag_mapping)
      @edit = {:id  => nil,
               :new => {:options    => [["<All>", nil]],
                        :entity     => nil,
                        :label_name => nil,
                        :category   => nil}}
      render :partial => "ops/label_tag_mapping_form"
    end

    it 'entity should be disabled when editing an existing mapping' do
      expect(response.body).to include('<select name="entity" id="entity" class="selectpicker" disabled="disabled">')
    end

    it 'label should be disabled when editing an existing mapping' do
      expect(response.body).to include('<input type="text" name="label_name" id="label_name" maxlength="25" class="form-control" disabled="disabled" data-miq_observe')
    end

    it 'category should be enabled when editing an existing mapping' do
      expect(response.body).to include('<input type="text" name="category" id="category" maxlength="50" class="form-control" data-miq_observe')
    end
  end
end
