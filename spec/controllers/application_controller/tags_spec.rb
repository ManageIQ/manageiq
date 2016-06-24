describe ApplicationController  do
  context "tag_edit_build_screen" do
    def add_entry(cat, options)
      raise "entries can only be added to classifications" unless cat.category?
      # Inherit from parent classification
      options.merge!(:read_only    => cat.read_only,
                     :syntax       => cat.syntax,
                     :single_value => cat.single_value,
                     :ns           => cat.ns)
      options.merge!(:parent_id => cat.id) # Ugly way to set up a child
      FactoryGirl.create(:classification, options)
    end

    # creating record in different region
    def update_record_region(record)
      record.update_column(:id, record.id + MiqRegion.rails_sequence_factor)
    end

    # convert record id into region id
    def convert_to_region_id(id)
      MiqRegion.id_to_region(id)
    end

    before(:each) do
      # setup classification/entries with same name in different regions
      clergy = FactoryGirl.create(:classification, :description => "Clergy")
      add_entry(clergy, :name => "bishop", :description => "Bishop")

      # add another classification with different description,
      # then change description to be same as above after updating region id of record
      clergy2 = FactoryGirl.create(:classification, :description => "Clergy2")
      update_record_region(clergy2)
      clergy2.update_column(:description, "Clergy")

      clergy_bishop2 = add_entry(clergy2, :name => "bishop", :description => "Bishop")
      update_record_region(clergy_bishop2)

      allow(Classification).to receive(:my_region_number).and_return(convert_to_region_id(clergy_bishop2.id))
      @st = FactoryGirl.create(:service_template, :name => 'foo')
    end

    it "region id of classification/entries should match" do
      # only classification/entries from same region should be returned
      controller.instance_variable_set(:@edit, :new => {})
      controller.instance_variable_set(:@tagging, 'ServiceTemplate')
      controller.instance_variable_set(:@object_ids, [@st.id])

      controller.send(:tag_edit_build_screen)
      expect(convert_to_region_id(assigns(:categories)['Clergy']))
        .to eq(convert_to_region_id(assigns(:entries)['Bishop']))
    end
  end
end
