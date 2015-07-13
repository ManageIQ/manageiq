require "spec_helper"

describe ApplicationController  do
  describe "#get_tagdata" do
    let(:record) { active_record_instance_double("Host") }
    let(:user) { FactoryGirl.create(:user, :userid => "testuser") }

    before do
      login_as user
      record.stub(:tagged_with).with(:cat => user.userid).and_return("my tags")
      Classification.stub(:find_assigned_entries).with(record).and_return(classifications)
    end

    context "when classifications exist" do
      let(:parent) { double("Parent", :description => "Department") }
      let(:child1) { double("Child1", :parent => parent, :description => "Automotive") }
      let(:child2) { double("Child2", :parent => parent, :description => "Financial Services") }
      let(:classifications) { [child1, child2] }

      it "populates the assigned filters in the session" do
        controller.send(:get_tagdata, record)
        session[:assigned_filters]['Department'].should == ["Automotive", "Financial Services"]
        session[:mytags].should == "my tags"
      end
    end

    context "when classifications do not exist" do
      let(:classifications) { [] }

      it "sets the assigned filters to an empty hash in the session" do
        controller.send(:get_tagdata, record)
        session[:assigned_filters].should == {}
        session[:mytags].should == "my tags"
      end
    end
  end

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

      Classification.stub(:my_region_number).and_return(convert_to_region_id(clergy_bishop2.id))
      @st = FactoryGirl.create(:service_template, :name => 'foo')
    end

    it "region id of classification/entries should match" do
      # only classification/entries from same region should be returned
      controller.instance_variable_set(:@edit, :new => {})
      controller.instance_variable_set(:@tagging, 'ServiceTemplate')
      controller.instance_variable_set(:@object_ids, [@st.id])
      session[:assigned_filters] = {:Test => %w("Entry1 Entry2)}

      controller.send(:tag_edit_build_screen)
      convert_to_region_id(assigns(:categories)['Clergy']).should eq(convert_to_region_id(assigns(:entries)['Bishop']))
    end
  end
end
