RSpec.describe DialogFieldTagControl do
  def add_entry(cat, options)
    raise "entries can only be added to classifications" unless cat.category?
    # Inherit from parent classification
    options.merge!(:read_only => cat.read_only, :syntax => cat.syntax, :single_value => cat.single_value, :ns => cat.ns)
    options.merge!(:parent_id => cat.id) # Ugly way to set up a child
    FactoryBot.create(:classification, options)
  end

  context "dialog field tag control without options hash" do
    before do
      @df = FactoryBot.create(:dialog_field_tag_control, :label => 'test tag category', :name => 'test tag category')
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

    it "#force_multi_value" do
      expect(@df.force_multi_value).to be_truthy

      @df.force_single_value = true
      expect(@df.force_multi_value).to be_falsey
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
    before do
      @df = FactoryBot.create(:dialog_field_tag_control, :label => 'test tag category', :name => 'test tag category',
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
    before do
      @cat = FactoryBot.create(:classification, :description => "Auto Approve - Max CPU", :name => "prov_max_cpu", :single_value => 1)
      @df  = FactoryBot.create(:dialog_field_tag_control, :label => 'test tag category', :name => 'test tag category',
            :options => {:category_id => @cat.id, :category_name => 'category', :category_description => 'description'}
                               )
    end

    it "#single_value?" do
      expect(@df.single_value?).to be_truthy

      cat = FactoryBot.create(:classification, :description => "Auto Approve - Max Memory", :name => "prov_max_memory", :single_value => 0)
      df  = FactoryBot.create(:dialog_field_tag_control, :label => 'test tag category', :name => 'test tag category',
            :options => {:category_id => cat.id, :category_name => 'category', :category_description => 'description'}
                              )

      expect(df.single_value?).to be_falsey
    end
  end

  context "dialog field tag control and Classification seeded" do
    before do
      cat = FactoryBot.create(:classification, :description => "Environment", :name => "environment", :single_value => true)
      add_entry(cat, :name => "dev",  :description => "Development")
      add_entry(cat, :name => "test", :description => "Test")
      add_entry(cat, :name => "prod", :description => "Production")

      cat = FactoryBot.create(:classification, :description => "Department", :name => "department", :single_value => false)
      add_entry(cat, :name => "accounting",  :description => "Accounting")
      add_entry(cat, :name => "engineering", :description => "Engineering")
      add_entry(cat, :name => "marketing",   :description => "Marketing")
    end

    it ".allowed_tag_categories" do
      expected_array = Classification.is_category.where(:show => true, :read_only => false).includes(:tag).collect do |cat|
        {:id => cat.id, :description => cat.description, :single_value => cat.single_value}
      end.sort_by { |cat| cat[:description] }

      expect(DialogFieldTagControl.allowed_tag_categories).to match_array(expected_array)
    end

    context "with dialog field tag control without options hash" do
      before do
        @df  = FactoryBot.create(:dialog_field_tag_control, :label => 'test tag', :name => 'test tag', :options => {:force_single_select => true})
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

  describe "#values" do
    let(:dialog_field) { described_class.new(:options => options, :data_type => data_type, :required => required) }
    let(:options) { {:category_id => category_id, :sort_by => sort_by, :sort_order => sort_order, :force_single_value => single?} }
    let(:category_id) { 123 }
    let(:required) { false }
    let(:sort_by) { :none }
    let(:sort_order) { :ascending }
    let(:data_type) { "string" }
    let(:single?) { true }

    before do
      allow(Classification).to receive(:find_by).with(:id => category_id).and_return(classification)
    end

    shared_examples_for "DialogFieldTagControl#values when required is true" do
      let(:required) { true }

      context "singlevalue" do
        let(:single?) { true }

        it "the blank value uses 'Choose' for its name and description" do
          expect(dialog_field.values[0]).to eq(:id => nil, :name => "<Choose>", :description => "<Choose>")
        end
      end

      context "multi value" do
        let(:single?) { false }

        it "has no blank value" do
          expect(%w[<Choose> <None>]).to_not include(dialog_field.values[0][:name])
        end
      end
    end

    context "when the classification exists" do
      let(:classification) { instance_double("Classification", :entries => [entry1, entry2]) }
      let(:entry1) { instance_double("Classification", :id => 321, :name => "dog", :description => "Dog") }
      let(:entry2) { instance_double("Classification", :id => 312, :name => "cat", :description => "Cat") }

      context "when the sort by is set to :value" do
        let(:sort_by) { :value }

        context "when the data type is integer" do
          let(:data_type) { "integer" }
          let(:entry1) { instance_double("Classification", :id => 321, :name => "2dog", :description => "Dog") }
          let(:entry2) { instance_double("Classification", :id => 312, :name => "1cat", :description => "Cat") }

          context "when the sort order is descending" do
            let(:sort_order) { :descending }

            it_behaves_like "DialogFieldTagControl#values when required is true"

            it "sorts reverse by name converting to integer and adds a blank value to the front" do
              expect(dialog_field.values).to eq([
                {:id => nil, :name => "<None>", :description => "<None>"},
                {:id => 321, :name => "2dog", :description => "Dog"},
                {:id => 312, :name => "1cat", :description => "Cat"}
              ])
            end
          end

          context "when the sort order is not descending" do
            let(:sort_order) { :ascending }

            it_behaves_like "DialogFieldTagControl#values when required is true"

            it "sorts by name converting to integer and adds a blank value to the front" do
              expect(dialog_field.values).to eq([
                {:id => nil, :name => "<None>", :description => "<None>"},
                {:id => 312, :name => "1cat", :description => "Cat"},
                {:id => 321, :name => "2dog", :description => "Dog"}
              ])
            end
          end
        end

        context "when the data type is not integer" do
          context "when the sort order is descending" do
            let(:sort_order) { :descending }

            it_behaves_like "DialogFieldTagControl#values when required is true"

            it "sorts reverse by name and adds a blank value to the front" do
              expect(dialog_field.values).to eq([
                {:id => nil, :name => "<None>", :description => "<None>"},
                {:id => 321, :name => "dog", :description => "Dog"},
                {:id => 312, :name => "cat", :description => "Cat"}
              ])
            end
          end

          context "when the sort order is not descending" do
            let(:sort_order) { :ascending }

            it_behaves_like "DialogFieldTagControl#values when required is true"

            it "sorts by name and adds a blank value to the front" do
              expect(dialog_field.values).to eq([
                {:id => nil, :name => "<None>", :description => "<None>"},
                {:id => 312, :name => "cat", :description => "Cat"},
                {:id => 321, :name => "dog", :description => "Dog"}
              ])
            end
          end
        end
      end

      context "when the sort by is set to :none" do
        it_behaves_like "DialogFieldTagControl#values when required is true"

        it "returns the available tags in whatever order they came in as with a blank value first" do
          expect(dialog_field.values).to eq([
            {:id => nil, :name => "<None>", :description => "<None>"},
            {:id => 321, :name => "dog", :description => "Dog"},
            {:id => 312, :name => "cat", :description => "Cat"},
          ])
        end
      end
    end

    context "when the classification does not exist" do
      let(:classification) { nil }

      it "returns an empty array" do
        expect(dialog_field.values).to eq([])
      end
    end
  end
end
