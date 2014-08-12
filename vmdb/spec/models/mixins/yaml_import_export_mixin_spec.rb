require "spec_helper"

describe YAMLImportExportMixin do
  before do
    class TestClass
      include YAMLImportExportMixin
    end

    @report1 = FactoryGirl.create(:miq_report, :name => "test_report_1")
  end

  after do
    Object.send(:remove_const, "TestClass")
  end

  context ".export_to_array" do
    before  { @klass = MiqReport }
    subject { TestClass.export_to_array(@list, @klass) }

    it "invalid class" do
      @list, @klass = [12345], "xxx"
      subject.should == []
    end

    it "invalid instance" do
      @list = [12345]
      subject.should == []
    end

    it "single valid instance" do
      policy = FactoryGirl.create(:miq_policy, :name => "test_policy")
      @list = [@report1.id, policy.id]

      MiqPolicy.any_instance.should_receive(:export_to_array).never
      MiqReport.any_instance.should_receive(:export_to_array).once
      subject
    end

    it "multiple valid instances" do
      @report2 = FactoryGirl.create(:miq_report, :name => "test_report_2")
      @list = [@report1.id, @report2.id]

      subject.size.should == 2
    end
  end

  it ".export_to_yaml" do
    TestClass.should_receive(:export_to_array).once.with([@report1.id], MiqReport)
    TestClass.export_to_yaml([@report1.id], MiqReport)
  end

  context ".import" do
    subject { TestClass.import(@fd) }

    it "valid YAML file" do
      @fd = StringIO.new("---\na:")
      lambda { subject }.should_not raise_error
    end

    it "invalid YAML file" do
      @fd = StringIO.new("---\na:\nb")
      lambda { subject }.should raise_error("Invalid YAML file")
    end
  end
end
