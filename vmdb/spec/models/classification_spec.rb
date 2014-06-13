require "spec_helper"

describe Classification do
  DEFAULT_NAMESPACE = "/managed"

  def add_entry(cat, options)
    raise "entries can only be added to classifications" unless cat.category?
    # Inherit from parent classification
    options.merge!(:read_only => cat.read_only, :syntax => cat.syntax, :single_value => cat.single_value, :ns => cat.ns)
    options.merge!(:parent_id => cat.id) # Ugly way to set up a child
    entry = FactoryGirl.create(:classification, options)
  end

  context ".hash_all_by_type_and_name" do
    it "with entries duped across categories should return both entries" do
      clergy = FactoryGirl.create(:classification, :description=>"Clergy", :name=>"clergy", :single_value => 1)
      clergy_bishop = add_entry(clergy, :name=>"bishop", :description=>"Bishop")
      chess = FactoryGirl.create(:classification, :description=>"Chess", :name=>"chess", :single_value => 1)
      chess_bishop = add_entry(chess, :name=>"bishop", :description=>"Bishop")

      Classification.hash_all_by_type_and_name.should == {
        "clergy" => {
          :category => clergy,
          :entry => { "bishop" => clergy_bishop }
        },
        "chess" => {
          :category => chess,
          :entry => { "bishop" => chess_bishop }
        }
      }
    end
  end

  context "enforce_policy" do
    before(:each) do
      @cat = FactoryGirl.create(:classification, :description=>"Test category", :name=>"test_category")
      @tag = add_entry(@cat, :name=>"test_entry", :description=>"Test entry under test category")
    end

    it "enforce_policy on sub-classed vm" do
      MiqEvent.stub(:raise_evm_event).and_return(true)

      vm = FactoryGirl.create(:vm_vmware, :name => "VM1")
      @tag.enforce_policy(vm, "fake_event")
    end

    it "enforce_policy on sub-classed host" do
      MiqEvent.stub(:raise_evm_event).and_return(true)

      host = FactoryGirl.create(:host_vmware_esx, :name => "HOST1")
      @tag.enforce_policy(host, "fake_event")
    end

  end

  context "with hierarchy" do
    before(:each) do
      cat = FactoryGirl.create(:classification, :description=>"Test category", :name=>"test_category")
      add_entry(cat, :name=>"test_entry", :description=>"Test entry under test category")
      add_entry(cat, :name=>"another_test_entry", :description=>"Another test entry under test category")

      cat = FactoryGirl.create(:classification, :description=>"Test single value category", :name=>"test_single_value_category", :single_value => 1)
      add_entry(cat, :name=>"single_entry_1", :description=>"Test entry 1 under single value category")
      add_entry(cat, :name=>"single_entry_2", :description=>"Test entry 2 under single value category")

      cat = FactoryGirl.create(:classification, :description=>"Test multi value category", :name=>"test_multi_value_category", :single_value => 0)
      add_entry(cat, :name=>"multi_entry_1", :description=>"Test entry 1 under multi value category")
      add_entry(cat, :name=>"multi_entry_2", :description=>"Test entry 2 under multi value category")

      @host1 = FactoryGirl.create(:host, :name => "HOST1", :hostname => "HOST1", :ipaddress => "123.456.789.012", :vmm_vendor => "vmware")
      @host2 = FactoryGirl.create(:host, :name => "HOST2", :hostname => "HOST2", :ipaddress => "123.456.789.012", :vmm_vendor => "vmware")
      @host3 = FactoryGirl.create(:host, :name => "HOST3", :hostname => "HOST3", :ipaddress => "123.456.789.012", :vmm_vendor => "vmware")

      @sti_inst = FactoryGirl.create(:cim_storage_extent)

      cat = Classification.find_by_name("test_category")
      cat.entries.each {|ent| ent.assign_entry_to(@host3) }
    end

    it "#destroy" do
      cat     = Classification.find_by_name("test_category")
      cat.should_not be_nil
      entries = cat.entries
      entries.length.should == 2

      cat.destroy
      entries.each { |e| Classification.find_by_id(e.id).should be_nil }
    end

    it "should test setup data" do
      cat = Classification.find_by_name("test_category")
      cat.should_not be_nil
      cat.tag.should_not be_nil
      cat.name = File.split(cat.tag.name).last
      cat.name.should_not be_nil
    end

    it "should test add entry" do
      cat = Classification.find_by_name("test_category")
      ent = add_entry(cat, :name=>"test_add_entry", :description=>"Test add entry under test category", :single_value => false)

      ent.should be_valid
      cat.id.to_i.should == ent.parent_id
      cat.entries.length.should == 3
    end

    it "should test add entry directly (without calling add_entry)" do
      cat = Classification.find_by_name("test_category")
      ent = cat.children.new(:name => "test_add_entry_1", :description => "Test add entry under test category 1")
      ent.save(:validate => false)

      cat.reload
      cat.id.to_i.should == ent.parent_id
      cat.entries.length.should == 3
    end

    it "should test categories" do
      # Find all classification categories
      cats = Classification.categories
      cats.length.should == 3
    end

    it "should test create duplicate category" do
      lambda {
        cat = FactoryGirl.create(:classification, :description=>"Test category", :name=>"test_category")
      }.should raise_error(ActiveRecord::RecordInvalid)
    end

    it "should test update category" do
      cat = Classification.find_by_name("test_category")
      cat.name = "test_update_entry"
      cat.should be_valid
      cat.save.should be_true
    end

    it "should test add duplicate entry" do
      cat = Classification.find_by_name("test_category")
      ent = add_entry(cat, :name=>"test_add_dup_entry", :description=>"Test entry under test category 1", :single_value => false)
      ent.should be_valid
      lambda {
        ent = add_entry(cat, :name=>"test_add_dup_entry", :description=>"Test entry under test category 2", :single_value => false)
      }.should raise_error(ActiveRecord::RecordInvalid)
    end

    it "should test update entry" do
      cat = Classification.find_by_name("test_category")
      ent = cat.entries[0]
      ent.name = "test_update_entry"
      ent.should be_valid
      ent.save.should be_true
    end

    it "should test update entry to duplicate" do
      cat = Classification.find_by_name("test_category")
      ent = cat.entries[0]
      ent.name = cat.entries[1].name
      ent.should_not be_valid
      ent.errors[:name].should == ["has already been taken"]
    end

    it "should test invalid name" do
      names = [
        '<My_Name>',
        'My Name',
        'My_Name_is...',
        '123456789_123456789_123456789_1'
      ]
      names.each {|name|
        cat = Classification.new(:name => name, :parent_id => 0)
        cat.should_not be_valid
        cat.should have(1).error_on(:name)
      }
    end

    it "should test assign single entry to" do
      h = Host.find_by_name "HOST1"
      cat = Classification.find_by_name "test_single_value_category"
      ent1 = cat.entries[0]
      ent2 = cat.entries[1]

      ent1.assign_entry_to(h)
      # assert_equal h.tag_list(:ns => DEFAULT_NAMESPACE, :cat => ent1.parent.name), ent1.name
      Host.find_tagged_with(:any => ent1.name, :ns => DEFAULT_NAMESPACE, :cat => ent1.parent.name).should_not be_empty

      ent2.assign_entry_to(h)
      # assert_equal h.tag_list(:ns => DEFAULT_NAMESPACE, :cat => ent2.parent.name), ent2.name
      Host.find_tagged_with(:any => ent2.name, :ns => DEFAULT_NAMESPACE, :cat => ent2.parent.name).should_not be_empty
      Host.find_tagged_with(:any => ent1.name, :ns => DEFAULT_NAMESPACE, :cat => ent1.parent.name).should be_empty
    end

    it "should test assign multi entry to" do
      h = Host.find_by_name "HOST2"
      cat = Classification.find_by_name "test_multi_value_category"
      ent1 = cat.entries[0]
      ent2 = cat.entries[1]

      ent1.assign_entry_to(h)
      Host.find_tagged_with(:any => ent1.name, :ns => DEFAULT_NAMESPACE, :cat => ent1.parent.name).should_not be_empty
      ent2.assign_entry_to(h)
      Host.find_tagged_with(:any => ent2.name, :ns => DEFAULT_NAMESPACE, :cat => ent2.parent.name).should_not be_empty
      Host.find_tagged_with(:any => ent1.name, :ns => DEFAULT_NAMESPACE, :cat => ent1.parent.name).should_not be_empty
      Host.find_tagged_with(:all => "#{ent1.name} #{ent2.name}", :ns => DEFAULT_NAMESPACE, :cat => ent1.parent.name).should_not be_empty
    end

    it "should test find by entry" do
      h = Host.find_by_name "HOST2"
      cat = Classification.find_by_name "test_multi_value_category"
      ent1 = cat.entries[0]

      ent1.assign_entry_to(h)
      ent1.find_by_entry("Host")[0].name.should == h.name
    end

    it "should test remove entry from" do
      h = Host.find_by_name "HOST2"
      cat = Classification.find_by_name "test_multi_value_category"
      ent1 = cat.entries[0]
      ent2 = cat.entries[1]

      ent1.assign_entry_to(h)
      ent2.assign_entry_to(h)
      Host.find_tagged_with(:all => "#{ent1.name} #{ent2.name}", :ns => DEFAULT_NAMESPACE, :cat => ent1.parent.name).should_not be_empty

      ent1.remove_entry_from(h)
      Host.find_tagged_with(:any => ent2.name, :ns => DEFAULT_NAMESPACE, :cat => ent2.parent.name).should_not be_empty
      Host.find_tagged_with(:any => ent1.name, :ns => DEFAULT_NAMESPACE, :cat => ent1.parent.name).should be_empty
    end

    it "should test find assigned entries" do
      h = Host.find_by_name "HOST3"
      Classification.find_assigned_entries(h).length.should == 2
    end

    it "should test to_tag" do
      cat = Classification.find_by_name("test_category")
      cat.should_not be_nil
      cat.entries.length.should == 2
      cat.entries.each { |ent| ent.to_tag.should == "/managed/#{cat.name}/#{ent.name}" }
    end

    it "should test assign single entry to an STI instance" do
      cat = Classification.find_by_name "test_single_value_category"
      ent1 = cat.entries[0]
      ent2 = cat.entries[1]

      ent1.assign_entry_to(@sti_inst)
      CimStorageExtent.find_tagged_with(:any => ent1.name, :ns => DEFAULT_NAMESPACE, :cat => ent1.parent.name).should_not be_empty

      ent2.assign_entry_to(@sti_inst)
      CimStorageExtent.find_tagged_with(:any => ent2.name, :ns => DEFAULT_NAMESPACE, :cat => ent2.parent.name).should_not be_empty
      CimStorageExtent.find_tagged_with(:any => ent1.name, :ns => DEFAULT_NAMESPACE, :cat => ent1.parent.name).should be_empty
    end

    it "should test find by entry for an STI instance" do
      cat = Classification.find_by_name "test_multi_value_category"
      ent1 = cat.entries[0]

      ent1.assign_entry_to(@sti_inst)
      ent1.find_by_entry("CimStorageExtent")[0].should == @sti_inst
    end

    it "should test remove entry from an STI instance" do
      cat = Classification.find_by_name "test_multi_value_category"
      ent1 = cat.entries[0]
      ent2 = cat.entries[1]

      ent1.assign_entry_to(@sti_inst)
      ent2.assign_entry_to(@sti_inst)
      CimStorageExtent.find_tagged_with(:all => "#{ent1.name} #{ent2.name}", :ns => DEFAULT_NAMESPACE, :cat => ent1.parent.name).should_not be_empty

      ent1.remove_entry_from(@sti_inst)
      CimStorageExtent.find_tagged_with(:any => ent2.name, :ns => DEFAULT_NAMESPACE, :cat => ent2.parent.name).should_not be_empty
      CimStorageExtent.find_tagged_with(:any => ent1.name, :ns => DEFAULT_NAMESPACE, :cat => ent1.parent.name).should be_empty
    end

    context "#bulk_assignemnt" do
      before do
        @options = {:model => "Host"}
        targets = [@host1, @host2, @host3]
        @options[:object_ids] = targets.collect(&:id)

        cat = Classification.find_by_name("test_category")
        @dels = cat.entries.collect
        @options[:delete_ids] = @dels.collect(&:id)

        cat = Classification.find_by_name("test_multi_value_category")
        @adds = cat.entries.collect
        @options[:add_ids] = @adds.collect(&:id)
      end

      it "normal case" do
        Classification.bulk_reassignment(@options)

        @dels.each do |d|
          Host.find_tagged_with(:any => d.name, :ns => DEFAULT_NAMESPACE, :cat => d.parent.name).should be_empty
        end

        @adds.each do |a|
          Host.find_tagged_with(:all => a.name, :ns => DEFAULT_NAMESPACE, :cat => a.parent.name).should_not be_empty
        end
      end

      it "with some errors" do
        MiqEvent.stub(:raise_evm_event).and_raise

        lambda { Classification.bulk_reassignment(@options) }.should raise_error

        @dels.each do |d|
          Host.find_tagged_with(:any => d.name, :ns => DEFAULT_NAMESPACE, :cat => d.parent.name).should_not be_empty
        end

        @adds.each do |a|
          Host.find_tagged_with(:all => a.name, :ns => DEFAULT_NAMESPACE, :cat => a.parent.name).should be_empty
        end
      end
    end

    context "#category" do
      it "for tag" do
        tag = Classification.find_by_name("test_category").children.first
        tag.category.should == "test_category"
      end

      it "for category" do
        Classification.find_by_name("test_category").category.should be_nil
      end
    end
  end
end
