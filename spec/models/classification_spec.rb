RSpec.describe Classification do
  context ".hash_all_by_type_and_name" do
    it "with entries duped across categories should return both entries" do
      clergy        = FactoryBot.create(:classification,     :name => "clergy", :single_value => 1)
      clergy_bishop = FactoryBot.create(:classification_tag, :name => "bishop", :parent => clergy)
      chess         = FactoryBot.create(:classification,     :name => "chess",  :single_value => 1)
      chess_bishop  = FactoryBot.create(:classification_tag, :name => "bishop", :parent => chess)

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

  it "validates description uniqueness" do
    c1 = described_class.create!(:name => "parent", :description => "this is getting annoying")
    described_class.create!(:name => "child", :description => "cat", :parent => c1)
    c2 = described_class.new(:name => "child", :description => "cat", :parent => c1)

    expect(c2.valid?).to be(false)
  end

  it "accesses database once when unchanged model is saved" do
    c1 = described_class.create!(:name => "parent", :description => "this is getting annoying")
    c2 = described_class.create!(:name => "child", :description => "cat", :parent => c1)

    expect { expect(c2.valid?).to be(true) }.to make_database_queries(:count => 1)
  end

  context "enforce_policy" do
    let(:tag) { FactoryBot.build(:classification_tag, :parent => FactoryBot.build(:classification)) }

    it "enforce_policy on sub-classed vm" do
      allow(MiqEvent).to receive(:raise_evm_event).and_return(true)

      vm = FactoryBot.build(:vm_vmware, :name => "VM1")
      tag.enforce_policy(vm, "fake_event")
    end

    it "enforce_policy on sub-classed host" do
      allow(MiqEvent).to receive(:raise_evm_event).and_return(true)

      host = FactoryBot.build(:host_vmware_esx)
      tag.enforce_policy(host, "fake_event")
    end
  end

  context "with hierarchy" do
    let(:host1) { FactoryBot.create(:host, :name => "HOST1") }
    let(:host2) { FactoryBot.create(:host, :name => "HOST2") }
    let(:host3) do
      FactoryBot.create(:host, :name => "HOST3").tap do |host|
        Classification.lookup_by_name("test_category").entries.each { |ent| ent.assign_entry_to(host) }
      end
    end
    let(:sti_inst) { FactoryBot.create(:template_vmware) }

    before do
      parent = FactoryBot.create(:classification, :name => "test_category")
      FactoryBot.create(:classification_tag,      :name => "test_entry",         :parent => parent)
      FactoryBot.create(:classification_tag,      :name => "another_test_entry", :parent => parent)

      parent = FactoryBot.create(:classification, :name => "test_single_value_category", :single_value => 1)
      FactoryBot.create(:classification_tag,      :name => "single_entry_1", :parent => parent)
      FactoryBot.create(:classification_tag,      :name => "single_entry_2", :parent => parent)

      parent = FactoryBot.create(:classification, :name => "test_multi_value_category", :single_value => 0)
      FactoryBot.create(:classification_tag,      :name => "multi_entry_1", :parent => parent)
      FactoryBot.create(:classification_tag,      :name => "multi_entry_2", :parent => parent)
    end

    describe ".classify" do
      let(:entry) { "test_entry" }
      let(:category) { "test_category" }
      before { @vm = FactoryBot.create(:vm) }

      it "returns detailed message if tag category not found" do
        category = "Hello, World"
        msg = Classification.classify(@vm, category, entry)
        expect(msg).to include("Tag category '#{category}' not found in region #{@vm.region_id}")
      end

      it "returns detailed message message if tag entry not found" do
        entry = "Hello, World"
        msg = Classification.classify(@vm, category, entry)
        expect(msg).to include("Tag name '#{entry}' not found  in region #{@vm.region_id}")
      end

      it "returns detailed message message if object already tagged with tag namespace set to 'none'" do
        allow(@vm).to receive(:is_tagged_with?)
        allow(@vm).to receive(:is_tagged_with?).with("/managed/test_category/test_entry", :ns => "none").and_return(true)
        msg = Classification.classify(@vm, category, entry)
        expect(msg).to include("Object already tagged with tag namespace set to 'none'")
      end

      it "assign tag entry to object if tag category and tag name exist and returns 'SUCCESS'" do
        expect(Classification.classify(@vm, category, entry)).to include("SUCCESS")
      end
    end

    context "#destroy" do
      it "a category deletes all entries" do
        cat = Classification.lookup_by_name("test_category")
        expect(cat).to_not be_nil
        entries = cat.entries
        expect(entries.length).to eq(2)

        cat.destroy
        entries.each { |e| expect(Classification.find_by(:id => e.id)).to be_nil }
      end

      it "a category deletes assignments referenced by its entries" do
        cat = Classification.lookup_by_name("test_category")
        assignment_tag = "/chargeback_rate/assigned_to/vm/tag/managed/test_category/test_entry"

        Tag.create!(:name => assignment_tag)
        expect(Tag.exists?(:name => assignment_tag)).to be true

        cat.destroy

        expect(Tag.exists?(:name => assignment_tag)).to be false
      end

      it "a category does not delete assignments that are close but do not match its tag" do
        cat = Classification.lookup_by_name("test_category")
        assignment_tag = "/chargeback_rate/assigned_to/vm/tag/managed/test_category/test_entry"
        another_tag1 = Tag.create(:name => "/policy_set/assigned_to/vm/tag/managed/test_category/test_entry1")
        another_tag2 = Tag.create(:name => "/chargeback_rate/assigned_to/vm/tag/managed/test_category1/test_entry")

        Tag.create!(:name => assignment_tag)

        cat.destroy

        expect(Tag.exists?(:name => assignment_tag)).to be false
        expect(Tag.exists?(:name => another_tag1.name)).to be true
        expect(Tag.exists?(:name => another_tag2.name)).to be true
      end

      it "an entry deletes assignments where its tag is referenced" do
        cat = Classification.lookup_by_name("test_category")
        ent = cat.entries.find { |e| e.name == "test_entry" }
        assignment_tag = "/chargeback_rate/assigned_to/vm/tag/managed/test_category/test_entry"

        Tag.create!(:name => assignment_tag)
        expect(Tag.exists?(:name => assignment_tag)).to be true

        ent.destroy

        expect(Tag.exists?(:name => assignment_tag)).to be false
      end
    end

    it "should test setup data" do
      cat = Classification.lookup_by_name("test_category")
      expect(cat).to_not be_nil
      expect(cat.tag).to_not be_nil
      expect(File.split(cat.tag.name).last).to_not be_nil
    end

    it "should test add entry" do
      cat = Classification.lookup_by_name("test_category")
      ent = FactoryBot.create(:classification_tag, :name => "test_add_entry", :parent => cat)

      expect(ent).to be_valid
      expect(cat.id.to_i).to eq(ent.parent_id)
      expect(cat.entries.length).to eq(3)
    end

    it "should test add entry directly (without calling add_entry)" do
      cat = Classification.lookup_by_name("test_category")
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
        FactoryBot.create(:classification, :name => "test_category")
      end.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "should test update category" do
      cat = Classification.lookup_by_name("test_category")
      cat.name = "test_update_entry"

      expect(cat).to      be_valid
      expect(cat.save).to be_truthy
    end

    it "should test add duplicate entry" do
      cat = Classification.lookup_by_name("test_category")
      ent = FactoryBot.create(:classification_tag, :name => "test_add_dup_entry", :parent => cat)

      expect(ent).to be_valid
      expect do
        FactoryBot.create(:classification_tag, :name => "test_add_dup_entry", :parent => cat)
      end.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "should test update entry" do
      cat = Classification.lookup_by_name("test_category")
      ent = cat.entries[0]
      ent.name = "test_update_entry"

      expect(ent).to      be_valid
      expect(ent.save).to be_truthy
    end

    it "should test update entry to duplicate" do
      cat = Classification.lookup_by_name("test_category")
      ent = cat.entries[0]
      ent.name = cat.entries[1].name

      expect(ent).to_not be_valid
      expect(ent.errors[:name]).to eq(["has already been taken"])
    end

    it "should test invalid name" do
      ['<My_Name>',
       'My Name',
       'My_Name_is...',
       '123456789_123456789_123456789_123456789_123456789_1'
      ].each do |name|
        cat = Classification.is_category.new(:name => name)

        expect(cat).to_not be_valid
        expect(cat.errors[:name].size).to eq(1)
      end
    end

    it "should be able to produce valid names" do
      ['<My_Name>',
       'My Name',
       'My_Name_is...',
       '123456789_123456789_123456789_123456789_123456789_1'
      ].each do |name|
        good_name = Classification.sanitize_name(name)
        cat = Classification.is_category.new(:name => good_name, :description => name)
        expect(cat).to be_valid
      end
    end

    it "should test assign single entry to" do
      cat = Classification.lookup_by_name "test_single_value_category"
      ent1 = cat.entries[0]
      ent2 = cat.entries[1]

      ent1.assign_entry_to(host1)
      expect(any_tagged_with(Host, ent1.name, ent1.parent.name)).to eq([host1])
      expect(any_tagged_with(Host, full_tag_name(ent1))).to eq([host1])
      expect(all_tagged_with(Host, ent1.name, ent1.parent.name)).to eq([host1])

      ent2.assign_entry_to(host1)
      expect(any_tagged_with(Host, ent2.name, ent2.parent.name)).to eq([host1])
      expect(any_tagged_with(Host, ent1.name, ent1.parent.name)).not_to eq([host1])
    end

    it "should test assign multi entry to" do
      cat = Classification.lookup_by_name "test_multi_value_category"
      ent1 = cat.entries[0]
      ent2 = cat.entries[1]

      ent1.assign_entry_to(host2)
      expect(any_tagged_with(Host, ent1.name, ent1.parent.name)).to eq([host2])
      expect(all_tagged_with(Host, ent1.name, ent1.parent.name)).to eq([host2])

      expect(any_tagged_with(Host, [ent1.name, ent2.name], ent1.parent.name)).to eq([host2])
      expect(all_tagged_with(Host, [ent1.name, ent2.name], ent1.parent.name)).to be_empty

      ent2.assign_entry_to(host2)
      expect(any_tagged_with(Host, ent2.name, ent2.parent.name)).to eq([host2])
      expect(any_tagged_with(Host, ent1.name, ent1.parent.name)).to eq([host2])
      expect(all_tagged_with(Host, "#{ent1.name} #{ent2.name}", ent1.parent.name)).to eq([host2])
      expect(any_tagged_with(Host, [ent2.name, ent1.name], ent2.parent.name)).to eq([host2])
      expect(any_tagged_with(Host, [full_tag_name(ent2), full_tag_name(ent1)])).to eq([host2])
    end

    it "find with multiple tags" do
      cat1 = Classification.lookup_by_name "test_single_value_category"
      ent11 = cat1.entries[0]
      ent12 = cat1.entries[1]

      cat2 = Classification.lookup_by_name "test_multi_value_category"
      ent21 = cat2.entries[0]
      ent22 = cat2.entries[1]

      ent11.assign_entry_to(host2)
      ent21.assign_entry_to(host2)

      # success
      expect(any_tagged_with(Host, [[full_tag_name(ent12), full_tag_name(ent11)], [full_tag_name(ent21)]])).to eq([host2])
      expect(all_tagged_with(Host, [[full_tag_name(ent11)], [full_tag_name(ent11)]])).to eq([host2])

      # failure
      expect(all_tagged_with(Host, [[full_tag_name(ent12), full_tag_name(ent11)], [full_tag_name(ent21)]])
            ).not_to eq([host2])
      expect(all_tagged_with(Host, [[full_tag_name(ent11)], [full_tag_name(ent22)]])).not_to eq([host2])
      expect(all_tagged_with(Host, [[full_tag_name(ent12)], [full_tag_name(ent21)]])).not_to eq([host2])
    end

    it "finds tagged items with order clause" do
      cat1 = Classification.lookup_by_name "test_single_value_category"
      ent11 = cat1.entries[0]

      ent11.assign_entry_to(host1)

      expect(all_tagged_with(Host.order('name'), ent11.name, ent11.parent.name)).to eq([host1])
      expect(any_tagged_with(Host.order('name'), ent11.name, ent11.parent.name)).to eq([host1])

      expect(all_tagged_with(Host.order(Arel.sql('lower(name)')), ent11.name, ent11.parent.name)).to eq([host1])
      expect(any_tagged_with(Host.order(Arel.sql('lower(name)')), ent11.name, ent11.parent.name)).to eq([host1])

      expect(all_tagged_with(Host.order(Host.arel_table[:name].lower), ent11.name, ent11.parent.name)).to eq([host1])
      expect(any_tagged_with(Host.order(Host.arel_table[:name].lower), ent11.name, ent11.parent.name)).to eq([host1])
    end

    it "should test lookup by entry" do
      cat = Classification.lookup_by_name "test_multi_value_category"
      ent1 = cat.entries[0]

      ent1.assign_entry_to(host2)
      expect(ent1.lookup_by_entry("Host")[0].name).to eq(host2.name)
    end

    it "should test remove entry from" do
      cat = Classification.lookup_by_name "test_multi_value_category"
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
      cat = Classification.lookup_by_name("test_category")

      expect(cat).to_not be_nil
      expect(cat.entries.length).to eq(2)
      cat.entries.each { |ent| expect(ent.to_tag).to eq("/managed/#{cat.name}/#{ent.name}") }
    end

    it "should test assign single entry to an STI instance" do
      cat = Classification.lookup_by_name "test_single_value_category"
      ent1 = cat.entries[0]
      ent2 = cat.entries[1]

      ent1.assign_entry_to(sti_inst)
      expect(any_tagged_with(MiqTemplate, ent1.name, ent1.parent.name)).to_not be_empty

      ent2.assign_entry_to(sti_inst)
      expect(any_tagged_with(MiqTemplate, ent2.name, ent2.parent.name)).to_not be_empty
      expect(any_tagged_with(MiqTemplate, ent1.name, ent1.parent.name)).to     be_empty
    end

    it "should test find by entry for an STI instance" do
      cat = Classification.lookup_by_name "test_multi_value_category"
      ent1 = cat.entries[0]

      ent1.assign_entry_to(sti_inst)
      expect(ent1.lookup_by_entry("MiqTemplate")[0]).to eq(sti_inst)
    end

    it "should test remove entry from an STI instance" do
      cat = Classification.lookup_by_name "test_multi_value_category"
      ent1 = cat.entries[0]
      ent2 = cat.entries[1]

      ent1.assign_entry_to(sti_inst)
      ent2.assign_entry_to(sti_inst)
      expect(all_tagged_with(MiqTemplate, "#{ent1.name} #{ent2.name}", ent1.parent.name)).to_not be_empty

      ent1.remove_entry_from(sti_inst)
      expect(any_tagged_with(MiqTemplate, ent2.name, ent2.parent.name)).to_not be_empty
      expect(any_tagged_with(MiqTemplate, ent1.name, ent1.parent.name)).to be_empty
    end

    context "#bulk_assignemnt" do
      before do
        @options = {:model => "Host"}
        targets = [host1, host2, host3]
        @options[:object_ids] = targets.collect(&:id)

        cat = Classification.lookup_by_name("test_category")
        @dels = cat.entries.collect
        @options[:delete_ids] = @dels.collect(&:id)

        cat = Classification.lookup_by_name("test_multi_value_category")
        @adds = cat.entries.collect
        @options[:add_ids] = @adds.collect(&:id)
      end

      it "normal case" do
        Classification.bulk_reassignment(@options)

        @dels.each { |d| expect(any_tagged_with(Host, d.name, d.parent.name)).to     be_empty }
        @adds.each { |a| expect(all_tagged_with(Host, a.name, a.parent.name)).to_not be_empty }
      end

      it "with some errors" do
        allow(MiqEvent).to receive(:raise_evm_event).and_raise

        expect { Classification.bulk_reassignment(@options) }
          .to raise_error(RuntimeError, /Failures occurred during bulk reassignment/)

        @dels.each { |d| expect(any_tagged_with(Host, d.name, d.parent.name)).to_not be_empty }
        @adds.each { |a| expect(all_tagged_with(Host, a.name, a.parent.name)).to     be_empty }
      end
    end

    context "#category" do
      it "for tag" do
        tag = Classification.lookup_by_name("test_category").children.first
        expect(tag.category).to eq("test_category")
      end

      it "for category" do
        expect(Classification.lookup_by_name("test_category").category).to be_nil
      end
    end
  end

  describe ".seed" do
    before do
      allow(YAML).to receive(:load_file).and_return([
        {:name         => "cc",
         :description  => "Cost Center",
         :example_text => "Cost Center",
         :read_only    => "0",
         :syntax       => "string",
         :show         => true,
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
        Classification.is_entry.destroy_all
        expect(Classification.count).to eq(1)

        Classification.seed
        expect(Classification.count).to eq(1)
      end

      it "does not re-seed user-modified default categories" do
        # If categories' names are edited they auto-save a different associated tag
        # This tests that if seeding category and it's invalid (due to uniqueness constraints)
        # then seeding still doesn't fail.
        cat = Classification.is_category.find_by!(:description => "Cost Center")
        allow(YAML).to receive(:load_file).and_call_original
        cat.update!(:name => "new_name")
        expect {
          2.times.each { Classification.seed }
        }.to_not raise_error
      end
    end

    it "does not re-seed existing categories" do
      category = FactoryBot.create(:classification_cost_center,
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

  describe '.find_by_name' do
    let(:my_region_number) { Classification.my_region_number }
    let(:other_region) { Classification.my_region_number + 1 }
    let(:other_region_id) { other_region * Classification.rails_sequence_factor + 1 }

    before do
      @local = FactoryBot.create(:classification, :name => "test_category1")
      FactoryBot.create(:classification, :name => "test_category3")

      FactoryBot.create(:tag, :name => "/managed/test_category2", :id => other_region_id)
      @remote = FactoryBot.create(:classification, :name => "test_category2", :id => other_region_id)
    end

    it "created classification in other region" do
      expect(@remote.region_id).to eq(other_region)
      expect(@remote.reload.id).to eq(other_region_id)
      expect(@remote.tag_id).to eq(other_region_id)
      expect(@remote.tag.region_id).to eq(other_region)
    end

    it "finds in region" do
      local = Classification.lookup_by_name("test_category1", my_region_number)
      expect(local).to eq(@local)
      remote = Classification.lookup_by_name("test_category2", other_region)
      expect(remote).to eq(@remote)
    end

    it "filters out wrong region" do
      expect(Classification.lookup_by_name("test_category1", other_region)).to be_nil
      expect(Classification.lookup_by_name("test_category2", my_region_number)).to be_nil
    end

    it "finds in all regions" do
      expect(Classification.lookup_by_name("test_category1", nil)).to eq(@local)
      expect(Classification.lookup_by_name("test_category2", nil)).to eq(@remote)
    end

    it "finds in my region" do
      expect(Classification.lookup_by_name("test_category1")).to eq(@local)
      expect(Classification.lookup_by_name("test_category2")).to be_nil
    end
  end

  describe '.find_by_names' do
    let(:my_region_number) { Classification.my_region_number }
    let(:other_region) { Classification.my_region_number + 1 }
    let(:other_region_id) { other_region * Classification.rails_sequence_factor + 1 }

    before do
      @local = FactoryBot.create(:classification, :name => "test_category1")
      FactoryBot.create(:tag, :name => Classification.name2tag("test_category2"), :id => other_region_id)
      @remote = FactoryBot.create(:classification, :name => "test_category2", :id => other_region_id)
      FactoryBot.create(:classification, :name => "test_category3")
    end

    it "finds in region" do
      expect(Classification.lookup_by_names(%w[test_category1 test_category2], my_region_number)).to eq([@local])
      expect(Classification.lookup_by_names(%w[test_category1 test_category2], other_region)).to eq([@remote])
    end

    it "finds in all regions" do
      expect(Classification.lookup_by_names(%w[test_category1 test_category2], nil)).to match_array([@local, @remote])
    end

    it "finds in my region" do
      Classification.lookup_by_name(%w[test_category1 test_category2])
      expect(Classification.lookup_by_names(%w[test_category1 test_category2])).to eq([@local])
    end
  end

  describe "name2tag" do
    let(:root_ns)   { "/managed" }
    let(:parent_ns) { "/managed/test_category" }
    let(:entry_ns)  { "/managed/test_category/test_entry" }
    let(:parent) { FactoryBot.create(:classification, :name => "test_category") }

    it "creates parent tag" do
      expect(Classification.name2tag("test_category")).to eq(parent_ns)
    end

    it "creates tag with name and ns" do
      expect(Classification.name2tag("test_entry", nil, parent_ns)).to eq(entry_ns)
      expect(Classification.name2tag("test_category", nil, root_ns)).to eq(parent_ns)
    end

    it "creates tag with name, ns, and parent_id" do
      expect(Classification.name2tag("test_entry", parent.id, root_ns)).to eq(entry_ns)
    end

    it "creates tag with name, ns and parent" do
      expect(Classification.name2tag("test_entry", parent, root_ns)).to eq(entry_ns)
    end
  end

  describe '.create_category!' do
    it "is a category" do
      c1 = Classification.create_category!(:name => 'a', :description => 'a')

      expect(c1).to be_category
    end
  end

  describe '#save' do
    let(:new_name) { "new_tag_name" }
    let(:category) { FactoryBot.create(:classification, :name => "category") }

    context "editing existing classification" do
      let(:classification) { FactoryBot.create(:classification_tag, :parent => category, :name => "some_tag_name") }
      it "doesn't assign new tag " do
        tag = classification.tag
        classification.update!(:name => new_name)
        classification.reload
        expect(tag.id).to eq classification.tag.id
        expect(classification.name).to eq(new_name)
        expect(classification.tag.name).to eq(Classification.name2tag(new_name, category))
      end
    end

    context "saving new classification" do
      it "creates new tag" do
        classification = Classification.create(:description => new_name, :parent => category, :name => new_name)
        expect(classification.tag).to be_present
        expect(classification.name).to eq(new_name)
        expect(classification.tag.name).to eq(Classification.name2tag(new_name, category))
      end
    end
  end

  describe '.create' do
    it "assigns proper tags" do
      FactoryBot.create(:classification_department_with_tags)
      Tag.all.each do |tag|
        expect(tag.name).to eq(Classification.name2tag(tag.classification.name, tag.classification.parent_id))
      end
    end
  end

  describe '.tag2human' do
    let!(:classification) { FactoryBot.create(:classification_department_with_tags) }

    it 'returns a human readible name' do
      tag = Tag.find_by(:name => "/managed/department/hr")
      expect(described_class.tag2human(tag.name)).to eq("Department: Human Resources")
    end
  end

  def all_tagged_with(target, all, category = nil)
    tagged_with(target, :all => all, :cat => category)
  end

  def any_tagged_with(target, any, category = nil)
    tagged_with(target, :any => any, :cat => category)
  end

  def tagged_with(target, options)
    target.find_tagged_with(options.merge!(:ns => Classification::DEFAULT_NAMESPACE))
  end

  def grouped_with(target, options)
    target.find_tags_by_grouping(options.merge!(:ns => Classification::DEFAULT_NAMESPACE))
  end

  def full_tag_name(tag)
    Classification.name2tag(tag.name, tag.parent, "") # avoid "managed", it will get added later
  end
end
