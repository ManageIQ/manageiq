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
end
