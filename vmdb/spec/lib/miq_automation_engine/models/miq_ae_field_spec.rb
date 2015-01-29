require "spec_helper"

describe MiqAeField do
  describe "#to_export_xml" do
    let(:default_value) { nil }
    let(:miq_ae_field) do
      described_class.new(
        :created_on    => Time.now,
        :default_value => default_value,
        :display_name  => "display_name",
        :id            => 123,
        :method_id     => 321,
        :updated_by    => "me",
        :updated_on    => Time.now
      )
    end

    context "when default_value is blank" do
      let(:expected_xml) do
        <<-XML
<MiqAeField name="" substitute="true" display_name="display_name"></MiqAeField>
        XML
      end

      it "does not include the default_value" do
        expect(miq_ae_field.to_export_xml).to eql(expected_xml.chomp)
      end
    end

    context "when default_value is not blank" do
      let(:default_value) { "default_value" }
      let(:expected_xml) do
        <<-XML
<MiqAeField name="" substitute="true" display_name="display_name">default_value</MiqAeField>
        XML
      end

      it "includes the default_value" do
        expect(miq_ae_field.to_export_xml).to eql(expected_xml.chomp)
      end
    end
  end

  context "legacy tests" do
    before(:each) do
      @c1 = MiqAeClass.create(:namespace => "TEST", :name => "fields_test")
    end

    it "should enforce necessary parameters upon create" do
      -> { @c1.ae_fields.new.save! }.should raise_error(ActiveRecord::RecordInvalid)
      # remove the invalid unsaved record in the association by clearing it
      @c1.ae_fields.clear
      f1 = @c1.ae_fields.build(:name => "TEST")
      f1.should_not be_nil
      f1.save!.should be_true
    end

    it "should not create fields with invalid names" do
      ["fie ld1", "fie-ld1", "fie:ld1"].each do |name|
        f1 = @c1.ae_fields.build(:name => name)
        f1.should_not be_nil
        -> { f1.save! }.should raise_error(ActiveRecord::RecordInvalid)
      end
    end

    it "should process boolean fields properly" do
      fname1 = "TEST_EVALUATE"
      f1 = @c1.ae_fields.build(:name => fname1)
      f1.save!.should be_true
      f1.substitute?.should be_true

      f1.substitute = false
      f1.save!.should be_true
      f1.substitute?.should be_false

      f1.substitute = nil
      f1.should be_valid

      f1.destroy

      f1 = @c1.ae_fields.build(:name => fname1, :substitute => false)
      f1.save!.should be_true
      f1.substitute?.should be_false

      f1.destroy

      f1 = @c1.ae_fields.build(:name => fname1, :substitute => "FRANK")
      # f1 = @c1.ae_fields.new
      f1.should be_valid
      f1.substitute?.should be_true
      f1.save!.should be_true

      f1.destroy
    end

    it "should set the updated_by field on save" do
      f1 =  @c1.ae_fields.create(:name => "field")
      f1.updated_by.should == 'system'
    end

    it "should validate unique case-independent names" do
      fname1 = "TEST_UNIQ"
      fname2 = "Test_Uniq"
      f1 = @c1.ae_fields.build(:name => fname1)
      f1.save!.should be_true
      f2 = @c1.ae_fields.build(:name => fname2)
      -> { f2.save! }.should raise_error(ActiveRecord::RecordInvalid)

      f2.destroy
      f1.destroy
    end

    it "should retrieve fields in priority order" do
      fname1 = "test1"
      fname2 = "test2"
      f2 = @c1.ae_fields.build(:name => fname2, :aetype => "attribute", :priority => 2)
      f2.save!.should be_true
      @c1.reload
      fields = @c1.ae_fields
      fields.length.should == 1
      fields[0].priority.should == 2

      f1 = @c1.ae_fields.build(:name => fname1, :aetype => "attribute", :priority => 1)
      f1.save!.should be_true
      @c1.reload

      fields = @c1.ae_fields
      fields.length.should == 2
      fields[0].priority.should == 1
      fields[1].priority.should == 2

      f2.destroy
      f1.destroy
    end

    it "should validate datatypes" do
      MiqAeField.available_datatypes.each do |datatype|
        f = @c1.ae_fields.build(:name => "fname_#{datatype}", :aetype => "attribute", :datatype => datatype)
        f.should be_valid
        f.save!.should be_true
      end
      @c1.reload.ae_fields.length.should == MiqAeField.available_datatypes.length

      @c1.ae_fields.destroy_all
      @c1.reload.ae_fields.length.should == 0

      %w(foo bar).each do |datatype|
        f = @c1.ae_fields.build(:name => "fname_#{datatype}", :aetype => "attribute", :datatype => datatype)
        f.should_not be_valid
      end
    end

    it "should not change boolean value for substitute field when updating existing AE field record" do
      field1 = @c1.ae_fields.create(:name => "test_field", :substitute => false)
      field1.substitute.should be_false
      field2 = MiqAeField.find_by_name_and_class_id("test_field", @c1.id)
      field2.save.should be_true
      field2.substitute.should be_false
    end

    it "should return editable as false if the parent namespace/class is not editable" do
      n1 = FactoryGirl.create(:miq_ae_namespace, :name => 'ns1', :priority => 10, :system => true)
      c1 = FactoryGirl.create(:miq_ae_class, :namespace_id => n1.id, :name => "foo")
      f1 = FactoryGirl.create(:miq_ae_field, :class_id => c1.id, :name => "foo_field")
      f1.should_not be_editable
    end

    it "should return editable as true if the parent namespace/class is editable" do
      n1 = FactoryGirl.create(:miq_ae_namespace, :name => 'ns1')
      c1 = FactoryGirl.create(:miq_ae_class, :namespace_id => n1.id, :name => "foo")
      f1 = FactoryGirl.create(:miq_ae_field, :class_id => c1.id, :name => "foo_field")
      f1.should be_editable
    end
  end
end
