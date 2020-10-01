RSpec.describe MiqAeInstance do
  it "accesses database once when unchanged model is saved" do
    d1 = FactoryBot.create(:miq_ae_system_domain, :name => 'dom1')
    n1 = FactoryBot.create(:miq_ae_namespace, :name => 'n1', :parent => d1)
    c1 = FactoryBot.create(:miq_ae_class, :namespace_id => n1.id, :name => "foo")
    i1 = FactoryBot.create(:miq_ae_instance, :class_id => c1.id, :name => "foo_instance")
    expect { i1.valid? }.not_to make_database_queries
  end

  context "legacy tests" do
    before do
      @user = FactoryBot.create(:user_with_group)
      @ns = FactoryBot.create(:miq_ae_namespace, :name => "TEST", :parent => FactoryBot.create(:miq_ae_domain))
      @c1 = MiqAeClass.create(:namespace_id => @ns.id, :name => "instance_test")
      @fname1 = "field1"
      @f1 = @c1.ae_fields.create(:name => @fname1)
    end

    it "should create instance" do
      iname1 = "instance1"
      i1 = @c1.ae_instances.build(:name => iname1)
      expect(i1).not_to be_nil
      expect(i1.save!).to be_truthy
      @c2 = MiqAeClass.find(@c1.id)
      expect(@c2).not_to be_nil
      expect(@c2.ae_instances).not_to be_nil
      expect(@c2.ae_instances.count).to eq(1)
      i1.destroy
    end

    it "should lookup instance by name" do
      iname = "instance"
      instance = @c1.ae_instances.create(:name => iname)

      expect(MiqAeInstance.lookup_by_name(iname)).to eq(instance)
    end

    it "should set the updated_by field on save" do
      i1 = @c1.ae_instances.create(:name => "instance1")
      expect(i1.updated_by).to eq('system')
    end

    it "should not create instances with invalid names" do
      ["insta nce1", "insta:nce1"].each do |iname|
        i1 = @c1.ae_instances.build(:name => iname)
        expect(i1).not_to be_nil
        expect { i1.save! }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    it "should create instances with valid names" do
      ["insta-nce1", "insta.nce1"].each do |iname|
        i1 = @c1.ae_instances.build(:name => iname)
        expect(i1).not_to be_nil
        expect { i1.save! }.to_not raise_error
      end
    end

    it "should properly get and set instance fields" do
      iname1 = "instance1"
      i1 = @c1.ae_instances.create(:name => iname1)

      value1 = "value1"
      value2 = "value2"
      fname_bad = "fieldX"

      # Set/Get a value that doesn't yet exist, by field name
      expect(i1.get_field_value(@fname1)).to be_nil
      expect { i1.set_field_value(@fname1, value1) }.to_not raise_error
      expect(i1.get_field_value(@fname1)).to eq(value1)

      # SetGet a value that already exists, by field name
      expect { i1.set_field_value(@fname1, value2) }.to_not raise_error
      expect(i1.get_field_value(@fname1)).to eq(value2)

      # Set/Get a value of a field that does not exist, by field name
      expect { i1.set_field_value(fname_bad, value1) }.to raise_error(MiqAeException::FieldNotFound)
      expect { i1.get_field_value(fname_bad) }.to raise_error(MiqAeException::FieldNotFound)

      i1.ae_values.destroy_all

      # Set/Get a value that doesn't yet exist, by field
      expect(i1.get_field_value(@f1)).to be_nil
      expect { i1.set_field_value(@f1, value1) }.to_not raise_error
      expect(i1.get_field_value(@f1)).to eq(value1)

      # SetGet a value that already exists, by field
      expect { i1.set_field_value(@f1, value2) }.to_not raise_error
      expect(i1.get_field_value(@f1)).to eq(value2)

      # Set/Get a value of a field from a different class
      c2 = MiqAeClass.create(:namespace => @ns.name, :name => "instance_test2")
      fname2 = "field2"
      f2 = c2.ae_fields.create(:name => fname2)

      #   by field name
      expect { i1.set_field_value(fname2, value1) }.to raise_error(MiqAeException::FieldNotFound)
      expect { i1.get_field_value(fname2)         }.to raise_error(MiqAeException::FieldNotFound)

      #   by field
      expect { i1.set_field_value(f2, value1) }.to raise_error(MiqAeException::FieldNotFound)
      expect { i1.get_field_value(f2)         }.to raise_error(MiqAeException::FieldNotFound)

      f2.destroy
      c2.destroy
      i1.destroy
    end

    it "should properly get and set password fields" do
      fname1        = "password"
      default_value = "secret"
      f1 = @c1.ae_fields.create(:name => fname1, :datatype => "password", :default_value => default_value)

      iname1 = "instance1"
      i1 = @c1.ae_instances.create(:name => iname1)

      value1 = "value1"
      value2 = "value2"

      # Set/Get a value that doesn't yet exist, by field name
      expect(MiqAePassword.decrypt(f1.default_value)).to eq(default_value)
      f1.default_value = nil
      expect(f1.default_value).to be_nil
      f1.default_value = default_value
      expect(MiqAePassword.decrypt(f1.default_value)).to eq(default_value)

      # Set/Get a value that doesn't yet exist, by field name
      expect(i1.get_field_value(fname1)).to be_nil
      expect { i1.set_field_value(fname1, value1) }.to_not raise_error
      expect(MiqAePassword.decrypt(i1.get_field_value(fname1))).to eq(value1)

      # SetGet a value that already exists, by field name
      expect { i1.set_field_value(fname1, value2) }.to_not raise_error
      expect(MiqAePassword.decrypt(i1.get_field_value(fname1))).to eq(value2)

      i1.destroy
      f1.destroy
    end

    it "should destroy field and be reflected in instance" do
      fname2 = "field2"
      iname1 = "instance1"
      value1 = "value1"
      f2 = @c1.ae_fields.create(:name => fname2)
      i1 = @c1.ae_instances.create(:name => iname1)

      expect { i1.set_field_value(f2, value1) }.to_not raise_error
      expect(i1.get_field_value(f2)).to eq(value1)

      f2_id = f2.id
      f2.destroy
      i1.reload

      expect(MiqAeValue.where(:field_id => f2_id)).to be_empty
      expect { i1.set_field_value(fname2, value1) }.to raise_error(MiqAeException::FieldNotFound)
      expect { i1.get_field_value(fname2)         }.to raise_error(MiqAeException::FieldNotFound)
    end

    it "should return editable as false if the parent namespace/class is not editable" do
      d1 = FactoryBot.create(:miq_ae_system_domain, :tenant => User.current_tenant)
      n1 = FactoryBot.create(:miq_ae_namespace, :parent => d1)
      c1 = FactoryBot.create(:miq_ae_class, :namespace_id => n1.id, :name => "foo")
      i1 = FactoryBot.create(:miq_ae_instance, :class_id => c1.id, :name => "foo_instance")
      expect(i1.editable?(@user)).to be_falsey
    end

    it "should return editable as true if the parent namespace/class is editable" do
      User.current_user = @user
      d1 = FactoryBot.create(:miq_ae_domain, :tenant => User.current_tenant)
      n1 = FactoryBot.create(:miq_ae_namespace, :parent => d1)
      c1 = FactoryBot.create(:miq_ae_class, :namespace_id => n1.id, :name => "foo")
      i1 = FactoryBot.create(:miq_ae_instance, :class_id => c1.id, :name => "foo_instance")
      expect(i1.editable?(@user)).to be_truthy
    end
  end

  describe "#to_export_xml" do
    let(:miq_ae_instance) do
      described_class.new(
        :ae_class           => ae_class,
        :ae_values          => ae_values,
        :created_on         => Time.zone.now,
        :id                 => 123,
        :updated_by         => "me",
        :updated_by_user_id => 321,
        :updated_on         => Time.zone.now
      )
    end

    let(:ae_class) { MiqAeClass.new(:ae_fields => [ae_field1, ae_field2]) }
    let(:ae_field1) { MiqAeField.new(:priority => 100) }
    let(:ae_field2) { MiqAeField.new(:priority => 1) }
    let(:ae_value) { MiqAeValue.new(:field_id => ae_field1.id) }
    let(:ae_values) { [ae_value] }

    before do
      allow(ae_field1).to receive(:id).and_return(42)
      allow(ae_field2).to receive(:id).and_return(84)

      allow(ae_value).to receive(:to_export_xml) do |options|
        options[:builder].ae_value
      end
    end

    it "produces the expected xml" do
      expected_xml = <<-XML
<MiqAeInstance name=""><ae_value/></MiqAeInstance>
      XML

      expect(miq_ae_instance.to_export_xml).to eq(expected_xml.chomp)
    end
  end

  context "#copy" do
    before do
      @d1 = FactoryBot.create(:miq_ae_domain, :name => "domain1", :priority => 1)
      @ns1 = FactoryBot.create(:miq_ae_namespace, :name => "ns1", :parent => @d1)
      @cls1 = FactoryBot.create(:miq_ae_class, :name => "cls1", :namespace_id => @ns1.id)
      @i1 = FactoryBot.create(:miq_ae_instance, :class_id => @cls1.id, :name => "foo_instance1")
      @i2 = FactoryBot.create(:miq_ae_instance, :class_id => @cls1.id, :name => "foo_instance2")

      @d2 = FactoryBot.create(:miq_ae_domain, :name => "domain2", :priority => 2)
      @ns2 = FactoryBot.create(:miq_ae_namespace, :name => "ns2", :parent => @d2)
    end

    it "copies instances under specified namespace" do
      options = {
        :domain             => @d2.name,
        :namespace          => @ns2.name,
        :overwrite_location => true,
        :ids                => [@i1.id, @i2.id]
      }

      res = MiqAeInstance.copy(options)
      expect(res.count).to eq(2)
    end

    it "copy instances under same namespace raise error when class exists" do
      options = {
        :domain             => @d1.name,
        :namespace          => @ns1.name,
        :overwrite_location => false,
        :ids                => [@i1.id, @i2.id]
      }

      expect { MiqAeInstance.copy(options) }.to raise_error(RuntimeError)
    end

    it "replaces instances under same namespace when class exists" do
      options = {
        :domain             => @d2.name,
        :namespace          => @ns2.name,
        :overwrite_location => true,
        :ids                => [@i1.id, @i2.id]
      }

      res = MiqAeInstance.copy(options)
      expect(res.count).to eq(2)
    end
  end

  it "#domain" do
    d1 = FactoryBot.create(:miq_ae_system_domain, :name => 'dom1')
    n1 = FactoryBot.create(:miq_ae_namespace, :name => 'n1', :parent => d1)
    c1 = FactoryBot.create(:miq_ae_class, :namespace_id => n1.id, :name => "foo")
    i1 = FactoryBot.create(:miq_ae_instance, :class_id => c1.id, :name => "foo_instance")
    expect(i1.domain.name).to eql('dom1')
  end

  describe '#get_homonymic_across_domains' do
    let(:u1) { FactoryBot.create(:user_with_group, :name => 'user1') }
    let(:d1) { FactoryBot.create(:miq_ae_domain, :name => 'dom1', :priority => 1) }
    let(:d2) { FactoryBot.create(:miq_ae_domain, :name => 'dom2', :priority => 2) }
    let(:n1) { FactoryBot.create(:miq_ae_namespace, :parent => d1, :name => "namespace") }
    let(:n2) { FactoryBot.create(:miq_ae_namespace, :parent => d2, :name => "namespace") }
    let(:c1) { FactoryBot.create(:miq_ae_class, :namespace_id => n1.id, :name => "class") }
    let(:c2) { FactoryBot.create(:miq_ae_class, :namespace_id => n2.id, :name => "class") }
    let!(:i1) { FactoryBot.create(:miq_ae_instance, :class_id => c1.id, :name => "instance") }
    let!(:i2) { FactoryBot.create(:miq_ae_instance, :class_id => c2.id, :name => "instance") }

    it 'returns sorted matches' do
      expect(run_method(u1, "namespace/class/instance", true, false)).to eq([i2, i1])
    end

    context 'with disabled domains' do
      before { d1.update(:enabled => false) }

      it 'returns only enabled domains' do
        expect(run_method(u1, "namespace/class/instance", true, false)).to eq([i2])
      end

      it 'returns all domains' do
        expect(run_method(u1, "namespace/class/instance", false, false)).to eq([i2, i1])
      end
    end

    context 'with tenancy' do
      let(:t1) { FactoryBot.create(:tenant, :name => 'tenant1') }
      let(:t2) { FactoryBot.create(:tenant, :name => 'tenant2') }
      let(:g1) { FactoryBot.create(:miq_group, :tenant => t1) }
      let(:u1) { FactoryBot.create(:user, :name => 'user1', :miq_groups => [g1]) }
      let(:d1) { FactoryBot.create(:miq_ae_domain, :name => 'dom1', :priority => 1, :tenant => t1) }
      let(:d2) { FactoryBot.create(:miq_ae_domain, :name => 'dom2', :priority => 2, :tenant => t2) }

      it 'returns only visible domains' do
        expect(run_method(u1, "namespace/class/instance", true, false)).to eq([i1])
      end
    end

    def run_method(user, path, enabled, prefix)
      MiqAeInstance.get_homonymic_across_domains(user, path, enabled, :prefix => prefix)
    end
  end
end
