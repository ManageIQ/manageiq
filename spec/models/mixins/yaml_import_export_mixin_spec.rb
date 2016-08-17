describe YAMLImportExportMixin do
  let(:test_class) { Class.new { include YAMLImportExportMixin } }

  before do
    @report1 = FactoryGirl.create(:miq_report, :name => "test_report_1")
  end

  context ".export_to_array" do
    before  { @klass = MiqReport }
    subject { test_class.export_to_array(@list, @klass) }

    it "invalid class" do
      @list, @klass = [12345], "xxx"
      expect(subject).to eq([])
    end

    it "invalid instance" do
      @list = [12345]
      expect(subject).to eq([])
    end

    it "single valid instance" do
      policy = FactoryGirl.create(:miq_policy, :name => "test_policy")
      @list = [@report1.id, policy.id]

      expect_any_instance_of(MiqPolicy).to receive(:export_to_array).never
      expect_any_instance_of(MiqReport).to receive(:export_to_array).once
      subject
    end

    it "multiple valid instances" do
      @report2 = FactoryGirl.create(:miq_report, :name => "test_report_2")
      @list = [@report1.id, @report2.id]

      expect(subject.size).to eq(2)
    end
  end

  it ".export_to_yaml" do
    expect(test_class).to receive(:export_to_array).once.with([@report1.id], MiqReport)
    test_class.export_to_yaml([@report1.id], MiqReport)
  end

  context ".import" do
    subject { test_class }

    it "valid YAML file" do
      @fd = StringIO.new("---\na:")
      # if it gets to import_from_array, then it did not choke on yml
      expect(subject).to receive(:import_from_array)
      subject.import(@fd)
    end

    it "invalid YAML file" do
      @fd = StringIO.new("---\na:\nb")
      expect { subject.import(@fd) }.to raise_error("Invalid YAML file")
    end
  end
end
