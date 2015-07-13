require "spec_helper"

describe MiqAeInstance do
  context "legacy tests" do
    before(:each) do
      @c1 = MiqAeClass.create(:namespace => "TEST", :name => "instance_test")
      @fname1 = "field1"
      @f1 = @c1.ae_fields.create(:name => @fname1)
    end

    it "should create instance" do
      iname1 = "instance1"
      i1 = @c1.ae_instances.build(:name => iname1)
      i1.should_not be_nil
      i1.save!.should be_true
      @c2 = MiqAeClass.find(@c1.id)
      @c2.should_not be_nil
      @c2.ae_instances.should_not be_nil
      @c2.ae_instances.count.should == 1
      i1.destroy
    end

    it "should set the updated_by field on save" do
      i1 = @c1.ae_instances.create(:name => "instance1")
      i1.updated_by.should == 'system'
    end

    it "should not create instances with invalid names" do
      ["insta nce1", "insta:nce1"].each do |iname|
        i1 = @c1.ae_instances.build(:name => iname)
        i1.should_not be_nil
        lambda { i1.save! }.should raise_error(ActiveRecord::RecordInvalid)
      end
    end

    it "should create instances with valid names" do
      ["insta-nce1", "insta.nce1"].each do |iname|
        i1 = @c1.ae_instances.build(:name => iname)
        i1.should_not be_nil
        lambda { i1.save! }.should_not raise_error
      end
    end

    it "should properly get and set instance fields" do
      iname1 = "instance1"
      i1 = @c1.ae_instances.create(:name => iname1)

      value1 = "value1"
      value2 = "value2"
      fname_bad = "fieldX"

      # Set/Get a value that doesn't yet exist, by field name
      i1.get_field_value(@fname1).should be_nil
      lambda { i1.set_field_value(@fname1, value1) }.should_not raise_error
      i1.get_field_value(@fname1).should == value1

      # SetGet a value that already exists, by field name
      lambda { i1.set_field_value(@fname1, value2) }.should_not raise_error
      i1.get_field_value(@fname1).should == value2

      # Set/Get a value of a field that does not exist, by field name
      lambda { i1.set_field_value(fname_bad, value1) }.should raise_error(MiqAeException::FieldNotFound)
      lambda { i1.get_field_value(fname_bad) }.should raise_error(MiqAeException::FieldNotFound)

      i1.ae_values.destroy_all

      # Set/Get a value that doesn't yet exist, by field
      i1.get_field_value(@f1).should be_nil
      lambda { i1.set_field_value(@f1, value1) }.should_not raise_error
      i1.get_field_value(@f1).should == value1

      # SetGet a value that already exists, by field
      lambda { i1.set_field_value(@f1, value2) }.should_not raise_error
      i1.get_field_value(@f1).should == value2

      # Set/Get a value of a field from a different class
      c2 = MiqAeClass.create(:namespace => "TEST", :name => "instance_test2")
      fname2 = "field2"
      f2 = c2.ae_fields.create(:name => fname2)

      #   by field name
      lambda { i1.set_field_value(fname2, value1) }.should raise_error(MiqAeException::FieldNotFound)
      lambda { i1.get_field_value(fname2)         }.should raise_error(MiqAeException::FieldNotFound)

      #   by field
      lambda { i1.set_field_value(f2, value1) }.should raise_error(MiqAeException::FieldNotFound)
      lambda { i1.get_field_value(f2)         }.should raise_error(MiqAeException::FieldNotFound)

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
      MiqAePassword.decrypt(f1.default_value).should == default_value
      f1.default_value = nil
      f1.default_value.should be_nil
      f1.default_value = default_value
      MiqAePassword.decrypt(f1.default_value).should == default_value

      # Set/Get a value that doesn't yet exist, by field name
      i1.get_field_value(fname1).should be_nil
      lambda { i1.set_field_value(fname1, value1) }.should_not raise_error
      MiqAePassword.decrypt(i1.get_field_value(fname1)).should == value1

      # SetGet a value that already exists, by field name
      lambda { i1.set_field_value(fname1, value2) }.should_not raise_error
      MiqAePassword.decrypt(i1.get_field_value(fname1)).should == value2

      i1.destroy
      f1.destroy
    end

    it "should destroy field and be reflected in instance" do
      fname2 = "field2"
      iname1 = "instance1"
      value1 = "value1"
      f2 = @c1.ae_fields.create(:name => fname2)
      i1 = @c1.ae_instances.create(:name => iname1)

      lambda { i1.set_field_value(f2, value1) }.should_not raise_error
      i1.get_field_value(f2).should == value1

      f2_id = f2.id
      f2.destroy
      i1.reload

      MiqAeValue.where(:field_id => f2_id).should be_empty
      lambda { i1.set_field_value(fname2, value1) }.should raise_error(MiqAeException::FieldNotFound)
      lambda { i1.get_field_value(fname2)         }.should raise_error(MiqAeException::FieldNotFound)
    end

    it "should return editable as false if the parent namespace/class is not editable" do
      n1 = FactoryGirl.create(:miq_ae_namespace, :name => 'ns1', :priority => 10, :system => true)
      c1 = FactoryGirl.create(:miq_ae_class, :namespace_id => n1.id, :name => "foo")
      i1 = FactoryGirl.create(:miq_ae_instance, :class_id => c1.id, :name => "foo_instance")
      i1.should_not be_editable
    end

    it "should return editable as true if the parent namespace/class is editable" do
      n1 = FactoryGirl.create(:miq_ae_namespace, :name => 'ns1')
      c1 = FactoryGirl.create(:miq_ae_class, :namespace_id => n1.id, :name => "foo")
      i1 = FactoryGirl.create(:miq_ae_instance, :class_id => c1.id, :name => "foo_instance")
      i1.should be_editable
    end
  end

  describe "#to_export_xml" do
    let(:miq_ae_instance) do
      described_class.new(
        :ae_class           => ae_class,
        :ae_values          => ae_values,
        :created_on         => Time.now,
        :id                 => 123,
        :updated_by         => "me",
        :updated_by_user_id => 321,
        :updated_on         => Time.now
      )
    end

    let(:ae_class) { MiqAeClass.new(:ae_fields => [ae_field1, ae_field2]) }
    let(:ae_field1) { MiqAeField.new(:priority => 100) }
    let(:ae_field2) { MiqAeField.new(:priority => 1) }
    let(:ae_value) { MiqAeValue.new(:field_id => ae_field1.id) }
    let(:ae_values) { [ae_value] }

    before do
      ae_field1.stub(:id).and_return(42)
      ae_field2.stub(:id).and_return(84)

      ae_value.stub(:to_export_xml) do |options|
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
      @d1 = FactoryGirl.create(:miq_ae_namespace, :name => "domain1", :parent_id => nil, :priority => 1)
      @ns1 = FactoryGirl.create(:miq_ae_namespace, :name => "ns1", :parent_id => @d1.id)
      @cls1 = FactoryGirl.create(:miq_ae_class, :name => "cls1", :namespace_id => @ns1.id)
      @i1 = FactoryGirl.create(:miq_ae_instance, :class_id => @cls1.id, :name => "foo_instance1")
      @i2 = FactoryGirl.create(:miq_ae_instance, :class_id => @cls1.id, :name => "foo_instance2")

      @d2 = FactoryGirl.create(:miq_ae_namespace,
                               :name      => "domain2",
                               :parent_id => nil,
                               :priority  => 2,
                               :system    => false)
      @ns2 = FactoryGirl.create(:miq_ae_namespace, :name => "ns2", :parent_id => @d2.id)
    end

    it "copies instances under specified namespace" do
      options = {
        :domain             => @d2.name,
        :namespace          => @ns2.name,
        :overwrite_location => true,
        :ids                => [@i1.id, @i2.id]
      }

      res = MiqAeInstance.copy(options)
      res.count.should eq(2)
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
      res.count.should eq(2)
    end
  end

  it "#domain" do
    n1 = FactoryGirl.create(:miq_ae_domain, :name => 'dom1', :priority => 10, :system => true)
    c1 = FactoryGirl.create(:miq_ae_class, :namespace_id => n1.id, :name => "foo")
    i1 = FactoryGirl.create(:miq_ae_instance, :class_id => c1.id, :name => "foo_instance")
    i1.domain.name.should eql('dom1')
  end
end
