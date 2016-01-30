describe MiqAeNamespace do
  describe "name attribute validation" do
    subject { described_class.new }

    example "with no name" do
      subject.name = nil
      subject.valid?
      expect(subject.errors[:name]).to be_present
    end

    example "with a valid name" do
      subject.name = "name.space1"
      subject.valid?
      expect(subject.errors[:name]).to be_blank

      subject.name = "name-space1"
      subject.valid?
      expect(subject.errors[:name]).to be_blank

      subject.name = "name$space1"
      subject.valid?
      expect(subject.errors[:name]).to be_blank
    end

    example "with an invalid name" do
      subject.name = "name space1"
      subject.valid?
      expect(subject.errors[:name]).to be_present

      subject.name = "name:space1"
      subject.valid?
      expect(subject.errors[:name]).to be_present
    end
  end

  it "should find or create namespaces by fqname" do
    n1 = MiqAeNamespace.find_or_create_by_fqname("System/TEST")
    expect(n1).not_to be_nil
    expect(n1.save!).to be_truthy

    n2 = MiqAeNamespace.find_by_fqname("SYSTEM/test")
    expect(n2).not_to be_nil
    expect(n2).to eq(n1)

    n2 = MiqAeNamespace.find_by_fqname("system")
    expect(n2).not_to be_nil
    expect(n2).to eq(n1.parent)

    expect(MiqAeNamespace.find_by_fqname("TEST")).to be_nil
  end

  it "should set the updated_by field on save" do
    n1 = MiqAeNamespace.find_or_create_by_fqname("foo/bar")
    expect(n1.updated_by).to eq('system')

    n2 = MiqAeNamespace.find_by_fqname("foo")
    expect(n2.updated_by).to eq('system')
  end

  it "should have system property as false by default" do
    n1 = MiqAeNamespace.find_or_create_by_fqname("ns1/ns2")
    expect(n1.system).to be_falsey
    n2 = MiqAeNamespace.find_or_create_by_fqname("ns1")
    expect(n2.system).to be_falsey
  end

  it "should return editable as false if the parent has the system property set to true" do
    n1 = MiqAeNamespace.create!(:name => 'ns1', :priority => 10, :system => true)
    expect(n1).not_to be_editable

    n2 = MiqAeNamespace.create!(:name => 'ns2', :parent_id => n1.id)

    n3 = MiqAeNamespace.create!(:name => 'ns3', :parent_id => n2.id)
    expect(n3).not_to be_editable
  end

  it "should return editable as true if the namespace doesn't have the system property defined" do
    n1 = MiqAeNamespace.create!(:name => 'ns1')
    expect(n1).to be_editable
  end

  it 'find_by_fqname works with and without leading slash' do
    n1 = MiqAeNamespace.find_or_create_by_fqname("foo/bar")
    MiqAeNamespace.find_by_fqname('/foo/bar').id == n1.id
  end

  it 'empty namespace string should return nil' do
    expect(MiqAeNamespace.find_by_fqname(nil)).to be_nil
    expect(MiqAeNamespace.find_by_fqname('')).to be_nil
  end

  it "#domain" do
    n1 = MiqAeNamespace.find_or_create_by_fqname("System/TEST")
    expect(n1.domain.name).to eql('System')
  end
end
