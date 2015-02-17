require "spec_helper"

describe Tag do
  context ".filter_ns" do
    it "normal case" do
      tag1 = double
      tag1.stub(:name).and_return("/managed/abc")
      described_class.filter_ns([tag1], "/managed").should == ["abc"]
    end

    it "tag == namespace" do
      tag1 = double
      tag1.stub(:name).and_return("/managed")
      described_class.filter_ns([tag1], "/managed").should == []
    end

    it "tag == namespace and a second tag" do
      tag1 = double
      tag1.stub(:name).and_return("/managed")

      tag2 = double
      tag2.stub(:name).and_return("/managed/abc")
      described_class.filter_ns([tag1, tag2], "/managed").should == ["abc"]
    end

    it "empty tag" do
      tag1 = double
      tag1.stub(:name).and_return("/managed/")

      described_class.filter_ns([tag1], "/managed").should == []
    end

    it "nil namespace" do
      described_class.filter_ns(["/managed/abc"], nil).should == ["/managed/abc"]
    end

    it "nil namespace with nil tag" do
      described_class.filter_ns([nil, "/managed/abc"], nil).should == ["/managed/abc"]
    end
  end

  context "categorization" do
    before(:each) do
      FactoryGirl.create(:classification_department_with_tags)

      @tag_details    = {:category => "department", :name => "finance", :path => "/managed/department/finance"}
      @tag            = Tag.find_by_name(@tag_details[:path])
      @category       = Classification.find_by_name(@tag_details[:category], nil)
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
  end
end
