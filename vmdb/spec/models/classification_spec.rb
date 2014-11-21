require "spec_helper"

describe Classification do

  context ".hash_all_by_type_and_name" do
    it "with entries duped across categories should return both entries" do
      clergy        = FactoryGirl.create(:classification,     :name => "clergy", :single_value => 1)
      clergy_bishop = FactoryGirl.create(:classification_tag, :name => "bishop", :parent => clergy)
      chess         = FactoryGirl.create(:classification,     :name => "chess",  :single_value => 1)
      chess_bishop  = FactoryGirl.create(:classification_tag, :name => "bishop", :parent => chess)

      expect(Classification.hash_all_by_type_and_name).to include(
        "clergy" => {
          :category => clergy,
          :entry    => {"bishop" => clergy_bishop}
        },
        "chess"  => {
          :category => chess,
          :entry    => {"bishop" => chess_bishop}
        }
      )
    end
  end

  context "enforce_policy" do
    let(:tag) { FactoryGirl.build(:classification_tag, :parent => FactoryGirl.build(:classification)) }

    it "enforce_policy on sub-classed vm" do
      MiqEvent.stub(:raise_evm_event).and_return(true)

      vm = FactoryGirl.build(:vm_vmware, :name => "VM1")
      tag.enforce_policy(vm, "fake_event")
    end

    it "enforce_policy on sub-classed host" do
      MiqEvent.stub(:raise_evm_event).and_return(true)

      host = FactoryGirl.build(:host_vmware_esx)
      tag.enforce_policy(host, "fake_event")
    end
  end

  context "with hierarchy" do
    let(:host1) { FactoryGirl.create(:host, :name => "HOST1") }
    let(:host2) { FactoryGirl.create(:host, :name => "HOST2") }
    let(:host3) do
      FactoryGirl.create(:host, :name => "HOST3").tap do |host|
        Classification.find_by_name("test_category").entries.each { |ent| ent.assign_entry_to(host) }
      end
    end
    let(:sti_inst) { FactoryGirl.create(:cim_storage_extent) }

    before do
      parent = FactoryGirl.create(:classification, :name => "test_category")
      FactoryGirl.create(:classification_tag,      :name => "test_entry",         :parent => parent)
      FactoryGirl.create(:classification_tag,      :name => "another_test_entry", :parent => parent)

      parent = FactoryGirl.create(:classification, :name => "test_single_value_category", :single_value => 1)
      FactoryGirl.create(:classification_tag,      :name => "single_entry_1", :parent => parent)
      FactoryGirl.create(:classification_tag,      :name => "single_entry_2", :parent => parent)

      parent = FactoryGirl.create(:classification, :name => "test_multi_value_category", :single_value => 0)
      FactoryGirl.create(:classification_tag,      :name => "multi_entry_1", :parent => parent)
      FactoryGirl.create(:classification_tag,      :name => "multi_entry_2", :parent => parent)
    end

    it "#destroy" do
      cat = Classification.find_by_name("test_category")
      expect(cat).to_not be_nil
      entries = cat.entries
      expect(entries.length).to eq(2)

      cat.destroy
      entries.each { |e| expect(Classification.find_by_id(e.id)).to be_nil }
    end

    it "should test setup data" do
      cat = Classification.find_by_name("test_category")
      expect(cat).to_not be_nil
      expect(cat.tag).to_not be_nil
      expect(File.split(cat.tag.name).last).to_not be_nil
    end

    it "should test add entry" do
      cat = Classification.find_by_name("test_category")
      ent = FactoryGirl.create(:classification_tag, :name => "test_add_entry", :parent => cat)

      expect(ent).to be_valid
      expect(cat.id.to_i).to eq(ent.parent_id)
      expect(cat.entries.length).to eq(3)
    end

    it "should test add entry directly (without calling add_entry)" do
      cat = Classification.find_by_name("test_category")
      ent = cat.children.new(:name => "test_add_entry_1")
      ent.save(:validate => false)

      cat.reload
      expect(cat.id.to_i).to eq(ent.parent_id)
      expect(cat.entries.length).to eq(3)
    end

    it "should test categories" do
      # Find all classification categories
      expect(Classification.categories.length).to eq(3)
    end

    it "should test create duplicate category" do
      expect do
        FactoryGirl.create(:classification, :name => "test_category")
      end.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "should test update category" do
      cat = Classification.find_by_name("test_category")
      cat.name = "test_update_entry"

      expect(cat).to      be_valid
      expect(cat.save).to be_true
    end

    it "should test add duplicate entry" do
      cat = Classification.find_by_name("test_category")
      ent = FactoryGirl.create(:classification_tag, :name => "test_add_dup_entry", :parent => cat)

      expect(ent).to be_valid
      expect do
        FactoryGirl.create(:classification_tag, :name => "test_add_dup_entry", :parent => cat)
      end.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "should test update entry" do
      cat = Classification.find_by_name("test_category")
      ent = cat.entries[0]
      ent.name = "test_update_entry"

      expect(ent).to      be_valid
      expect(ent.save).to be_true
    end

    it "should test update entry to duplicate" do
      cat = Classification.find_by_name("test_category")
      ent = cat.entries[0]
      ent.name = cat.entries[1].name

      expect(ent).to_not be_valid
      expect(ent.errors[:name]).to eq(["has already been taken"])
    end

    it "should test invalid name" do
      ['<My_Name>',
       'My Name',
       'My_Name_is...',
       '123456789_123456789_123456789_1'
      ].each do |name|
        cat = Classification.new(:name => name, :parent_id => 0)

        expect(cat).to_not be_valid
        expect(cat).to     have(1).error_on(:name)
      end
    end

    it "should test assign single entry to" do
      cat = Classification.find_by_name "test_single_value_category"
      ent1 = cat.entries[0]
      ent2 = cat.entries[1]

      ent1.assign_entry_to(host1)
      expect(any_tagged_with(Host, ent1.name, ent1.parent.name)).to_not be_empty

      ent2.assign_entry_to(host1)
      expect(any_tagged_with(Host, ent2.name, ent2.parent.name)).to_not be_empty
      expect(any_tagged_with(Host, ent1.name, ent1.parent.name)).to     be_empty
    end

    it "should test assign multi entry to" do
      cat = Classification.find_by_name "test_multi_value_category"
      ent1 = cat.entries[0]
      ent2 = cat.entries[1]

      ent1.assign_entry_to(host2)
      expect(any_tagged_with(Host, ent1.name, ent1.parent.name)).to_not be_empty

      ent2.assign_entry_to(host2)
      expect(any_tagged_with(Host, ent2.name, ent2.parent.name)).to_not be_empty
      expect(any_tagged_with(Host, ent1.name, ent1.parent.name)).to_not be_empty
      expect(all_tagged_with(Host, "#{ent1.name} #{ent2.name}", ent1.parent.name)).to_not be_empty
    end

    it "should test find by entry" do
      cat = Classification.find_by_name "test_multi_value_category"
      ent1 = cat.entries[0]

      ent1.assign_entry_to(host2)
      expect(ent1.find_by_entry("Host")[0].name).to eq(host2.name)
    end

    it "should test remove entry from" do
      cat = Classification.find_by_name "test_multi_value_category"
      ent1 = cat.entries[0]
      ent2 = cat.entries[1]

      ent1.assign_entry_to(host2)
      ent2.assign_entry_to(host2)
      expect(all_tagged_with(Host, "#{ent1.name} #{ent2.name}", ent1.parent.name)).to_not be_empty

      ent1.remove_entry_from(host2)
      expect(any_tagged_with(Host, ent2.name, ent2.parent.name)).to_not be_empty
      expect(any_tagged_with(Host, ent1.name, ent1.parent.name)).to     be_empty
    end

    it "should test find assigned entries" do
      expect(Classification.find_assigned_entries(host3).length).to eq(2)
    end

    it "should test to_tag" do
      cat = Classification.find_by_name("test_category")

      expect(cat).to_not be_nil
      expect(cat.entries.length).to eq(2)
      cat.entries.each { |ent| expect(ent.to_tag).to eq("/managed/#{cat.name}/#{ent.name}") }
    end

    it "should test assign single entry to an STI instance" do
      cat = Classification.find_by_name "test_single_value_category"
      ent1 = cat.entries[0]
      ent2 = cat.entries[1]

      ent1.assign_entry_to(sti_inst)
      expect(any_tagged_with(CimStorageExtent, ent1.name, ent1.parent.name)).to_not be_empty

      ent2.assign_entry_to(sti_inst)
      expect(any_tagged_with(CimStorageExtent, ent2.name, ent2.parent.name)).to_not be_empty
      expect(any_tagged_with(CimStorageExtent, ent1.name, ent1.parent.name)).to     be_empty
    end

    it "should test find by entry for an STI instance" do
      cat = Classification.find_by_name "test_multi_value_category"
      ent1 = cat.entries[0]

      ent1.assign_entry_to(sti_inst)
      expect(ent1.find_by_entry("CimStorageExtent")[0]).to eq(sti_inst)
    end

    it "should test remove entry from an STI instance" do
      cat = Classification.find_by_name "test_multi_value_category"
      ent1 = cat.entries[0]
      ent2 = cat.entries[1]

      ent1.assign_entry_to(sti_inst)
      ent2.assign_entry_to(sti_inst)
      expect(all_tagged_with(CimStorageExtent, "#{ent1.name} #{ent2.name}", ent1.parent.name)).to_not be_empty

      ent1.remove_entry_from(sti_inst)
      expect(any_tagged_with(CimStorageExtent, ent2.name, ent2.parent.name)).to_not be_empty
      expect(any_tagged_with(CimStorageExtent, ent1.name, ent1.parent.name)).to be_empty
    end

    context "#bulk_assignemnt" do
      before do
        @options = {:model => "Host"}
        targets = [host1, host2, host3]
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

        @dels.each { |d| expect(any_tagged_with(Host, d.name, d.parent.name)).to     be_empty }
        @adds.each { |a| expect(all_tagged_with(Host, a.name, a.parent.name)).to_not be_empty }
      end

      it "with some errors" do
        MiqEvent.stub(:raise_evm_event).and_raise

        expect { Classification.bulk_reassignment(@options) }.to raise_error

        @dels.each { |d| expect(any_tagged_with(Host, d.name, d.parent.name)).to_not be_empty }
        @adds.each { |a| expect(all_tagged_with(Host, a.name, a.parent.name)).to     be_empty }
      end
    end

    context "#category" do
      it "for tag" do
        tag = Classification.find_by_name("test_category").children.first
        expect(tag.category).to eq("test_category")
      end

      it "for category" do
        expect(Classification.find_by_name("test_category").category).to be_nil
      end
    end
  end

  describe ".seed" do
    before do
      MiqRegion.seed

      YAML.stub(:load_file).and_return([
        {:name         => "cc",
         :description  => "Cost Center",
         :example_text => "Cost Center",
         :read_only    => "0",
         :syntax       => "string",
         :show         => true,
         :parent_id    => 0,
         :default      => true,
         :single_value => "1",
         :entries      => [{:description => "Cost Center 001", :name => "001"},
                           {:description => "Cost Center 002", :name => "002"}]
        }]
      )
    end

    context "after seeding" do
      before { Classification.seed }

      it "loads categories and tags" do
        expect(Classification.categories.count).to               eq(1)
        expect(Classification.categories.first.entries.count).to eq(2)
      end

      it "re-seeds deleted categories" do
        Classification.categories.first.destroy
        expect(Classification.count).to eq(0)

        Classification.seed
        expect(Classification.count).to eq(3)
      end

      it "does not re-seed deleted tags" do
        Classification.where("parent_id != 0").destroy_all
        expect(Classification.count).to eq(1)

        Classification.seed
        expect(Classification.count).to eq(1)
      end
    end

    it "does not re-seed existing categories" do
      category = FactoryGirl.create(:classification_cost_center,
                                    :description  => "user defined",
                                    :example_text => "user defined",
                                    :show         => false,
                                    :single_value => "0")

      category_attrs = category.attributes
      Classification.seed
      category.reload

      expect(category_attrs).to eq(category.attributes)
    end
  end

  def all_tagged_with(target, all, category)
    tagged_with(target, :all => all, :cat => category)
  end

  def any_tagged_with(target, any, category)
    tagged_with(target, :any => any, :cat => category)
  end

  def tagged_with(target, options)
    target.find_tagged_with(options.merge!(:ns => Classification::DEFAULT_NAMESPACE))
  end
end
