RSpec.describe Tag do
  describe ".list" do
    it "returns an empty string for something that is untaggable" do
      account = FactoryBot.create(:account)
      actual = described_class.list(account)
      expect(actual).to eq("")
    end
  end

  describe ".tags" do
    let!(:account) { FactoryBot.create(:account) }
    let!(:tag) { FactoryBot.create(:tag) }

    it "returns tags with tagged items" do
      Tagging.create(:taggable => account, :tag => tag)

      expect(Tag.tags).to eq [tag]
    end

    it "does not return tags without tagged items" do
      expect(Tag.tags).to eq []
    end

    it "can be filtered by taggable type" do
      Tagging.create(:taggable => account, :tag => tag)

      expect(Tag.tags(:taggable_type => 'Account')).to eq [tag]
      expect(Tag.tags(:taggable_type => 'User')).to eq []
    end

    context "when filtered by tag namespaces" do
      it "returns tag names w" do
        Tagging.create(:taggable => account, :tag => tag)

        expect(Tag.tags(:ns => '/namespace/cat')).to eq [tag.name.split('/').last]
        expect(Tag.tags(:ns => '/foo/bar')).to eq []
      end
    end
  end

  context ".filter_ns" do
    it "normal case" do
      tag1 = double
      allow(tag1).to receive(:name).and_return("/managed/abc")
      expect(described_class.filter_ns([tag1], "/managed")).to eq(["abc"])
    end

    it "tag == namespace" do
      tag1 = double
      allow(tag1).to receive(:name).and_return("/managed")
      expect(described_class.filter_ns([tag1], "/managed")).to eq([])
    end

    it "tag == namespace and a second tag" do
      tag1 = double
      allow(tag1).to receive(:name).and_return("/managed")

      tag2 = double
      allow(tag2).to receive(:name).and_return("/managed/abc")
      expect(described_class.filter_ns([tag1, tag2], "/managed")).to eq(["abc"])
    end

    it "empty tag" do
      tag1 = double
      allow(tag1).to receive(:name).and_return("/managed/")

      expect(described_class.filter_ns([tag1], "/managed")).to eq([])
    end

    it "nil namespace" do
      expect(described_class.filter_ns(["/managed/abc"], nil)).to eq(["/managed/abc"])
    end

    it "nil namespace with nil tag" do
      expect(described_class.filter_ns([nil, "/managed/abc"], nil)).to eq(["/managed/abc"])
    end
  end

  context "categorization" do
    before do
      FactoryBot.create(:classification_department_with_tags)

      @tag            = Tag.find_by(:name => "/managed/department/finance")
      @category       = Classification.lookup_by_name("department")
      @classification = @tag.classification
    end

    it "tag category should match category" do
      expect(@tag.category).to eq(@category)
    end

    it "tag show should reflect category show" do
      expect(@tag.show).to eq(@category.show)
    end

    it "tag categorization" do
      categorization = @tag.categorization
      expected_categorization = {"name"         => @classification.name,
                                 "description"  => @classification.description,
                                 "category"     => {"name" => @category.name, "description" => @category.description},
                                 "display_name" => "#{@category.description}: #{@classification.description}"}

      expect(categorization).to eq(expected_categorization)
    end

    it "tag with nil classification" do
      @tag.classification.delete
      expect(@tag.show).to be_falsey
      expect(@tag.categorization).to eq({})
    end

    it "category tags have no category" do
      category_tag = @tag.category.tag
      expect(category_tag.category).to be_nil
    end
  end

  describe ".find_by_classification_name" do
    let(:root_ns)   { "/managed" }
    let(:parent_ns) { "/managed/test_category" }
    let(:parent) { FactoryBot.create(:classification, :name => "test_category") }

    before do
      FactoryBot.create(:classification_tag,      :name => "test_entry",         :parent => parent)
      FactoryBot.create(:classification_tag,      :name => "another_test_entry", :parent => parent)
    end

    it "looks up tag by name" do
      expect(Tag.lookup_by_classification_name("test_category")).not_to be_nil
      expect(Tag.lookup_by_classification_name("test_category").name).to eq(parent_ns)
    end

    it "doesn't find non tag" do
      expect(Tag.lookup_by_classification_name("test_entry")).to be_nil
    end
  end

  describe "#==" do
    it "equals only itself" do
      tag1 = FactoryBot.build(:tag)
      tag2 = FactoryBot.build(:tag)
      expect(tag1).to eq tag1
      expect(tag1).not_to eq tag2
    end

    it "equals its name" do
      tag1 = FactoryBot.build(:tag, :name => '/a/b/c')
      expect(tag1).to eq '/a/b/c'
    end
  end

  describe "#destroy" do
    let(:miq_group)       { FactoryBot.create(:miq_group, :entitlement => Entitlement.create!) }
    let(:other_miq_group) { FactoryBot.create(:miq_group, :entitlement => Entitlement.create!) }
    let(:filters)         { [["/managed/prov_max_memory/test"], ["/managed/my_name/test"]] }
    let(:tag)             { FactoryBot.create(:tag, :name => "/managed/my_name/test") }

    before do
      miq_group.entitlement.set_managed_filters(filters)
      other_miq_group.entitlement.set_managed_filters(filters)
      [miq_group, other_miq_group].each(&:save)
    end

    it "destroys tag and remove it from all groups's managed filters" do
      tag.destroy

      expected_filters = [["/managed/prov_max_memory/test"]]
      MiqGroup.all.each { |group| expect(group.get_managed_filters).to match_array(expected_filters) }
      expect(Tag.all).to be_empty
    end
  end
end
