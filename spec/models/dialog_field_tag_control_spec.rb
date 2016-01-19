describe DialogFieldTagControl do
  def add_entry(cat, options)
    raise "entries can only be added to classifications" unless cat.category?
    # Inherit from parent classification
    options.merge!(:read_only => cat.read_only, :syntax => cat.syntax, :single_value => cat.single_value, :ns => cat.ns)
    options.merge!(:parent_id => cat.id) # Ugly way to set up a child
    entry = FactoryGirl.create(:classification, options)
  end

  context "dialog field tag control without options hash" do
    before(:each) do
      @df = FactoryGirl.create(:dialog_field_tag_control, :label => 'test tag category', :name => 'test tag category')
    end

    it "#category=" do
      @df.category = 1
      expect(@df.options[:category_id]).to eq(1)
    end

    it "#category" do
      expect(@df.category).to be_nil
    end

    it "#category_name" do
      expect(@df.category_name).to be_nil
    end

    it "#category_description" do
      expect(@df.category_description).to be_nil
    end

    it "#single_value?" do
      expect(@df.single_value?).to be_falsey

      @df.force_single_value = true
      expect(@df.single_value?).to be_truthy
    end

    it "#automate_key_name" do
      expect(@df.automate_key_name).to eq("Array::dialog_#{@df.name}")
    end

    describe "#initialize_with_values" do
      it "uses #automate_key_name for extracting initial dialog values" do
        dialog_value = "dummy dialog value"
        @df.initialize_with_values(@df.automate_key_name => dialog_value)
        expect(@df.value).to eq(dialog_value)
      end

      it "converts automate dialog value to Classification ids" do
        @df.initialize_with_values(@df.automate_key_name => "Classification::123,Classification::234")
        expect(@df.value).to eq("123,234")
      end
    end
  end

  context "dialog field tag control with with options hash and category" do
    before(:each) do
      @df = FactoryGirl.create(:dialog_field_tag_control, :label => 'test tag category', :name => 'test tag category',
            :options => {:force_single_value => true, :category_id => 1, :category_name => 'category', :category_description => 'description'}
                              )
    end

    it "#category" do
      expect(@df.category).to eq(1)
    end

    it "#category_name" do
      expect(@df.category_name).to eq('category')
    end

    it "#category_description" do
      expect(@df.category_description).to eq('description')
    end

    it "#single_value?" do
      expect(@df.single_value?).to be_truthy
    end
  end

  context "dialog field with tag control hash and tag categories" do
    before(:each) do
      @cat = FactoryGirl.create(:classification, :description => "Auto Approve - Max CPU", :name => "prov_max_cpu", :single_value => 1)
      @df  = FactoryGirl.create(:dialog_field_tag_control, :label => 'test tag category', :name => 'test tag category',
            :options => {:category_id => @cat.id, :category_name => 'category', :category_description => 'description'}
                               )
    end

    it "#single_value?" do
      expect(@df.single_value?).to be_truthy

      cat = FactoryGirl.create(:classification, :description => "Auto Approve - Max Memory", :name => "prov_max_memory", :single_value => 0)
      df  = FactoryGirl.create(:dialog_field_tag_control, :label => 'test tag category', :name => 'test tag category',
            :options => {:category_id => cat.id, :category_name => 'category', :category_description => 'description'}
                              )

      expect(df.single_value?).to be_falsey
    end
  end

  context "dialog field tag control and Classification seeded" do
    before(:each) do
      cat = FactoryGirl.create(:classification, :description => "Environment", :name => "environment",  :single_value => true,  :parent_id => 0)
      add_entry(cat, :name => "dev",  :description => "Development")
      add_entry(cat, :name => "test", :description => "Test")
      add_entry(cat, :name => "prod", :description => "Production")

      cat = FactoryGirl.create(:classification, :description => "Department",  :name => "department",   :single_value => false, :parent_id => 0)
      add_entry(cat, :name => "accounting",  :description => "Accounting")
      add_entry(cat, :name => "engineering", :description => "Engineering")
      add_entry(cat, :name => "marketing",   :description => "Marketing")
    end

    it ".allowed_tag_categories" do
      expected_array = Classification.where(:show => true, :parent_id => 0, :read_only => false).includes(:tag).collect do |cat|
        {:id => cat.id, :description => cat.description, :single_value => cat.single_value}
      end.sort_by { |cat| cat[:description] }

      expect(DialogFieldTagControl.allowed_tag_categories).to match_array(expected_array)
    end

    it ".category_tags" do
      category = Classification.where(:description => "Environment", :parent_id => 0).first
      expected_array = category.entries.collect { |t| {:id => t.id, :name => t.name, :description => t.description} }
      expect(DialogFieldTagControl.category_tags(category.id)).to match_array(expected_array)
    end

    context "with dialog field tag control without options hash" do
      before(:each) do
        @df  = FactoryGirl.create(:dialog_field_tag_control, :label => 'test tag', :name => 'test tag', :options => {:force_single_select => true})
      end

      it "#values" do
        cat = Classification.where(:description => "Environment").first
        @df.options[:category_id] = cat.id

        expected_array = cat.entries.collect { |c| {:id => c.id, :name => c.name, :description => c.description} }.sort_by { |cat| cat[:description] }
        expect(@df.values).to match_array(expected_array)
      end

      it "automate_output_value with an empty value" do
        expect(@df.automate_output_value).to eq("")
      end

      it "automate_output_value with an single value" do
        tag = Classification.first
        @df.value = tag.id.to_s
        expect(@df.automate_output_value).to eq("#{tag.class.name}::#{tag.id}")
      end

      it "automate_output_value with multiple values" do
        tags = [Classification.first, Classification.last]
        @df.value = tags.collect(&:id).join(",")
        expect(@df.automate_output_value.split(",")).to match_array tags.collect { |tag| "#{tag.class.name}::#{tag.id}" }
      end
    end
  end
end
