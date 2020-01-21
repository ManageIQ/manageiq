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

    context "with a duplicite names" do
      let(:domain) { FactoryBot.create(:miq_ae_domain) }
      let(:ns1)    { FactoryBot.create(:miq_ae_namespace, :name => 'ns1', :parent_id => domain.id) }

      before do
        FactoryBot.create(:miq_ae_namespace, :name => 'namespace', :parent_id => ns1.id)
      end

      it "with a distinct path is allowed" do
        # domain/ns1/namespace
        # domain/ns2/namespace
        ns2 = FactoryBot.create(:miq_ae_namespace, :name => 'ns2', :parent_id => domain.id)
        dup_namespace = FactoryBot.create(:miq_ae_namespace, :name => 'namespace', :parent_id => ns2.id)

        expect(ns2.valid?).to be_truthy
        expect(dup_namespace.valid?).to be_truthy
      end

      it "with a same path is not allowed" do
        # domain/ns1/namespace
        # domain/ns1/NAMESPACE
        expect do
          FactoryBot.create(:miq_ae_namespace, :name => 'NAMESPACE', :parent_id => ns1.id)
        end.to raise_error("Validation failed: MiqAeNamespace: Name has already been taken")
      end
    end
  end

  before do
    @user = FactoryBot.create(:user_with_group)
  end

  it "should find or create namespaces by fqname" do
    n1 = MiqAeNamespace.find_or_create_by_fqname("System/TEST")
    expect(n1).not_to be_nil
    expect(n1.save!).to be_truthy

    n2 = MiqAeNamespace.lookup_by_fqname("SYSTEM/test")
    expect(n2).not_to be_nil
    expect(n2).to eq(n1)

    n2 = MiqAeNamespace.lookup_by_fqname("system")
    expect(n2).not_to be_nil
    expect(n2).to eq(n1.parent)

    expect(MiqAeNamespace.lookup_by_fqname("TEST")).to be_nil
  end

  it "should set the updated_by field on save" do
    n1 = MiqAeNamespace.find_or_create_by_fqname("foo/bar")
    expect(n1.updated_by).to eq('system')

    n2 = MiqAeNamespace.lookup_by_fqname("foo")
    expect(n2.updated_by).to eq('system')
  end

  it "should return editable as false if the parent has the system property set to true" do
    n1 = FactoryBot.create(:miq_ae_system_domain, :tenant => @user.current_tenant)
    expect(n1.editable?(@user)).to be_falsey

    n2 = MiqAeNamespace.create!(:name => 'ns2', :parent_id => n1.id)

    n3 = MiqAeNamespace.create!(:name => 'ns3', :parent_id => n2.id)
    expect(n3.editable?(@user)).to be_falsey
  end

  it "should return editable as true if the namespace doesn't have the system property defined" do
    n1 = FactoryBot.create(:miq_ae_domain, :tenant => @user.current_tenant)
    expect(n1.editable?(@user)).to be_truthy
  end

  it "should raise exception if user is nil" do
    n1 = FactoryBot.create(:miq_ae_domain, :tenant => @user.current_tenant)
    expect { n1.editable?(nil) }.to raise_error(ArgumentError)
  end

  it 'find_by_fqname works with and without leading slash' do
    n1 = MiqAeNamespace.find_or_create_by_fqname("foo/bar")

    expect(MiqAeNamespace.lookup_by_fqname('/foo/bar').id).to eq(n1.id)
  end

  it 'empty namespace string should return nil' do
    expect(MiqAeNamespace.lookup_by_fqname(nil)).to be_nil
    expect(MiqAeNamespace.lookup_by_fqname('')).to be_nil
  end

  it "#domain" do
    n1 = MiqAeNamespace.find_or_create_by_fqname("System/TEST")
    expect(n1.domain.name).to eql('System')
  end
end
