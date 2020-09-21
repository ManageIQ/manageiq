RSpec.describe MiqAeField do
  describe "#to_export_xml" do
    let(:default_value) { nil }
    let(:miq_ae_field) do
      described_class.new(
        :created_on    => Time.zone.now,
        :default_value => default_value,
        :display_name  => "display_name",
        :id            => 123,
        :method_id     => 321,
        :updated_by    => "me",
        :updated_on    => Time.zone.now
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
    before do
      @ns = FactoryBot.create(:miq_ae_namespace, :name => "TEST", :parent => FactoryBot.create(:miq_ae_domain))
      @c1 = MiqAeClass.create(:namespace_id => @ns.id, :name => "fields_test")
      @user = FactoryBot.create(:user_with_group)
    end

    it "looks up by name" do
      field_name = "TEST"
      field = @c1.ae_fields.create(:name => field_name)

      expect(MiqAeField.lookup_by_name(field_name)).to eq(field)
    end

    it "should enforce necessary parameters upon create" do
      expect { @c1.ae_fields.new.save! }.to raise_error(ActiveRecord::RecordInvalid)
      # remove the invalid unsaved record in the association by clearing it
      @c1.ae_fields.clear
      f1 = @c1.ae_fields.build(:name => "TEST")
      expect(f1).not_to be_nil
      expect(f1.save!).to be_truthy
    end

    it "should not create fields with invalid names" do
      ["fie ld1", "fie-ld1", "fie:ld1"].each do |name|
        f1 = @c1.ae_fields.build(:name => name)
        expect(f1).not_to be_nil
        expect { f1.save! }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    it "doesn't access database (either via name uniqueness or set_user_info validation) when unchanged model is saved" do
      miq_ae_field = described_class.create!(:name => "display_name")
      expect { miq_ae_field.valid? }.not_to make_database_queries
    end

    describe "name validation" do
      it "doesn't allow spaces" do
        expect { FactoryBot.create(:miq_ae_field, :name => 'invalid name') }
          .to raise_error(ActiveRecord::RecordInvalid, / Name may contain only alphanumeric and _ characters/)
      end

      it "out of scope doesn't raise error" do
        ae_class = FactoryBot.create(:miq_ae_class)
        FactoryBot.create(:miq_ae_field, :class_id => ae_class.id, :name => 'non_unique_name')
        expect { FactoryBot.create(:miq_ae_field, :class_id => ae_class.id + 1, :name => 'non_unique_name') }
          .not_to raise_error
      end

      it "in scope raises error regardless of case" do
        ae_class = FactoryBot.create(:miq_ae_class)
        FactoryBot.create(:miq_ae_field, :class_id => ae_class.id, :name => 'non_unique_name')
        expect { FactoryBot.create(:miq_ae_field, :class_id => ae_class.id, :name => 'Non_unique_name') }
          .to raise_error(ActiveRecord::RecordInvalid, / Name has already been taken/)
      end

      it "doesn't allow nil" do
        expect { FactoryBot.create(:miq_ae_field, :name => nil) }
          .to raise_error(ActiveRecord::RecordInvalid, / Name can't be blank/)
      end

      it "doesn't allow hyphens" do
        expect { FactoryBot.create(:miq_ae_field, :name => 'invalid-name') }
          .to raise_error(ActiveRecord::RecordInvalid, / Name may contain only alphanumeric and _ characters/)
      end

      it "allows underscores" do
        expect { FactoryBot.create(:miq_ae_field, :name => 'valid_name') }.not_to raise_error
      end
    end

    it "should process boolean fields properly" do
      fname1 = "TEST_EVALUATE"
      f1 = @c1.ae_fields.build(:name => fname1)
      expect(f1.save!).to be_truthy
      expect(f1.substitute?).to be_truthy

      f1.substitute = false
      expect(f1.save!).to be_truthy
      expect(f1.substitute?).to be_falsey

      f1.substitute = nil
      expect(f1).to be_valid

      f1.destroy

      f1 = @c1.ae_fields.build(:name => fname1, :substitute => false)
      expect(f1.save!).to be_truthy
      expect(f1.substitute?).to be_falsey

      f1.destroy

      f1 = @c1.ae_fields.build(:name => fname1, :substitute => "FRANK")
      # f1 = @c1.ae_fields.new
      expect(f1).to be_valid
      expect(f1.substitute?).to be_truthy
      expect(f1.save!).to be_truthy

      f1.destroy
    end

    it "should set the updated_by field on save" do
      f1 =  @c1.ae_fields.create(:name => "field")
      expect(f1.updated_by).to eq('system')
    end

    it "should validate unique case-independent names" do
      fname1 = "TEST_UNIQ"
      fname2 = "Test_Uniq"
      f1 = @c1.ae_fields.build(:name => fname1)
      expect(f1.save!).to be_truthy
      f2 = @c1.ae_fields.build(:name => fname2)
      expect { f2.save! }.to raise_error(ActiveRecord::RecordInvalid)

      f2.destroy
      f1.destroy
    end

    it "should retrieve fields in priority order" do
      fname1 = "test1"
      fname2 = "test2"
      f2 = @c1.ae_fields.build(:name => fname2, :aetype => "attribute", :priority => 2)
      expect(f2.save!).to be_truthy
      @c1.reload
      fields = @c1.ae_fields
      expect(fields.length).to eq(1)
      expect(fields[0].priority).to eq(2)

      f1 = @c1.ae_fields.build(:name => fname1, :aetype => "attribute", :priority => 1)
      expect(f1.save!).to be_truthy
      @c1.reload

      fields = @c1.ae_fields
      expect(fields.length).to eq(2)
      expect(fields[0].priority).to eq(1)
      expect(fields[1].priority).to eq(2)

      f2.destroy
      f1.destroy
    end

    it "should validate datatypes" do
      MiqAeField.available_datatypes.each do |datatype|
        f = @c1.ae_fields.build(:name => "fname_#{datatype.gsub(/ /,'_')}",
                                :aetype => "attribute", :datatype => datatype)
        expect(f).to be_valid
        expect(f.save!).to be_truthy
      end
      expect(@c1.reload.ae_fields.length).to eq(MiqAeField.available_datatypes.length)

      @c1.ae_fields.destroy_all
      expect(@c1.reload.ae_fields.length).to eq(0)

      %w(foo bar).each do |datatype|
        f = @c1.ae_fields.build(:name => "fname_#{datatype}", :aetype => "attribute", :datatype => datatype)
        expect(f).not_to be_valid
      end
    end

    it "should not change boolean value for substitute field when updating existing AE field record" do
      field1 = @c1.ae_fields.create(:name => "test_field", :substitute => false)
      expect(field1.substitute).to be_falsey
      field2 = MiqAeField.find_by(:name => "test_field", :class_id => @c1.id)
      expect(field2.save).to be_truthy
      expect(field2.substitute).to be_falsey
    end

    it "should return editable as false if the parent namespace/class is not editable" do
      d1 = FactoryBot.create(:miq_ae_system_domain, :tenant => User.current_tenant)
      n1 = FactoryBot.create(:miq_ae_namespace, :parent => d1)
      c1 = FactoryBot.create(:miq_ae_class, :namespace_id => n1.id, :name => "foo")
      f1 = FactoryBot.create(:miq_ae_field, :class_id => c1.id, :name => "foo_field")
      expect(f1.editable?(@user)).to be_falsey
    end

    it "should return editable as true if the parent namespace/class is editable" do
      d1 = FactoryBot.create(:miq_ae_domain, :tenant => @user.current_tenant)
      n1 = FactoryBot.create(:miq_ae_namespace, :parent => d1)
      c1 = FactoryBot.create(:miq_ae_class, :namespace_id => n1.id, :name => "foo")
      f1 = FactoryBot.create(:miq_ae_field, :class_id => c1.id, :name => "foo_field")
      expect(f1.editable?(@user)).to be_truthy
    end
  end
end
