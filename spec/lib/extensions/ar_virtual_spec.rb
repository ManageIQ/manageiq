describe VirtualFields do
  context "TestClass" do
    before(:each) do
      class TestClassBase < ActiveRecord::Base
        self.abstract_class = true

        establish_connection :adapter => 'sqlite3', :database => ':memory:'

        include VirtualFields
      end

      ActiveRecord::Schema.define do
        def self.connection
          TestClassBase.connection
        end
        def self.set_pk_sequence!(*); end
        self.verbose = false

        create_table :test_classes do |t|
          t.integer :col1
        end
      end

      require 'ostruct'
      class TestClass < TestClassBase
        belongs_to :ref1, :class_name => 'TestClass', :foreign_key => :col1
      end
    end

    after(:each) do
      TestClassBase.remove_connection
      Object.send(:remove_const, :TestClass)
      Object.send(:remove_const, :TestClassBase)
    end

    it "should not have any virtual columns" do
      expect(TestClass.virtual_attribute_names).to be_empty

      expect(TestClass.attribute_names).to eq(TestClass.column_names)
    end

    context ".virtual_column" do
      it "with invalid parameters" do
        expect { TestClass.virtual_column :vcol1 }.to raise_error(ArgumentError)
      end

      it "with symbol name" do
        TestClass.virtual_column :vcol1, :type => :string
        expect(TestClass.attribute_names).to include("vcol1")
      end

      it "with string name" do
        TestClass.virtual_column "vcol1", :type => :string
        expect(TestClass.attribute_names).to include("vcol1")
      end

      it "with string type" do
        TestClass.virtual_column :vcol1, :type => :string
        expect(TestClass.type_for_attribute("vcol1")).to be_kind_of(ActiveModel::Type::String)
        expect(TestClass.type_for_attribute("vcol1").type).to eq(:string)
      end

      it "with symbol type" do
        TestClass.virtual_column :vcol1, :type => :symbol
        expect(TestClass.type_for_attribute("vcol1")).to be_kind_of(VirtualAttributes::Type::Symbol)
        expect(TestClass.type_for_attribute("vcol1").type).to eq(:symbol)
      end

      it "with string_set type" do
        TestClass.virtual_column :vcol1, :type => :string_set
        expect(TestClass.type_for_attribute("vcol1")).to be_kind_of(VirtualAttributes::Type::StringSet)
        expect(TestClass.type_for_attribute("vcol1").type).to eq(:string_set)
      end

      it "with numeric_set type" do
        TestClass.virtual_column :vcol1, :type => :numeric_set
        expect(TestClass.type_for_attribute("vcol1")).to be_kind_of(VirtualAttributes::Type::NumericSet)
        expect(TestClass.type_for_attribute("vcol1").type).to eq(:numeric_set)
      end

      it "without uses" do
        TestClass.virtual_column :vcol1, :type => :string
        expect(TestClass.virtual_includes(:vcol1)).to be_blank
      end

      it "with uses" do
        TestClass.virtual_column :vcol1, :type => :string, :uses => :col1
        expect(TestClass.virtual_includes(:vcol1)).to eq(:col1)
      end

      it "with arel" do
        TestClass.virtual_column :vcol1, :type => :boolean, :arel => -> (t) { t[:vcol].lower }
        expect(TestClass.arel_attribute("vcol1").to_sql).to eq(%{LOWER("test_classes"."vcol")})
      end
    end

    context ".virtual_columns=" do
      it "" do
        {
          :vcol1  => {:type => :string},
          "vcol2" => {:type => :string},
        }.each do |name, options|
          TestClass.virtual_column name, options
        end

        expect(TestClass.virtual_attribute_names).to match_array(["vcol1", "vcol2"])
      end

      it "with existing virtual columns" do
        TestClass.virtual_column :existing_vcol, :type => :string

        {
          :vcol1  => {:type => :string},
          "vcol2" => {:type => :string},
        }.each do |name, options|
          TestClass.virtual_column name, options
        end

        expect(TestClass.virtual_attribute_names).to match_array(["existing_vcol", "vcol1", "vcol2"])
      end
    end

    shared_examples_for "TestClass with virtual columns" do
      context "TestClass" do
        it ".virtual_attribute_names" do
          expect(TestClass.virtual_attribute_names).to match_array(@vcols_strs)
        end

        it ".attribute_names" do
          expect(TestClass.attribute_names).to match_array(@cols_strs)
        end

        context ".virtual_attribute?" do
          context "with virtual column" do
            it("as string") { expect(TestClass.virtual_attribute?("vcol1")).to be_truthy }
            it("as symbol") { expect(TestClass.virtual_attribute?(:vcol1)).to  be_truthy }
          end

          context "with column" do
            it("as string") { expect(TestClass.virtual_attribute?("col1")).not_to be_truthy }
            it("as symbol") { expect(TestClass.virtual_attribute?(:col1)).not_to  be_truthy }
          end
        end

        it ".remove_virtual_fields" do
          expect(TestClass.remove_virtual_fields(:vcol1)).to          be_nil
          expect(TestClass.remove_virtual_fields(:ref1)).to eq(:ref1)
          expect(TestClass.remove_virtual_fields([:vcol1])).to eq([])
          expect(TestClass.remove_virtual_fields([:vcol1, :ref1])).to eq([:ref1])
          expect(TestClass.remove_virtual_fields(:vcol1 => {})).to eq({})
          expect(TestClass.remove_virtual_fields(:vcol1 => {}, :ref1 => {})).to eq({:ref1 => {}})
        end
      end
    end

    shared_examples_for "TestSubclass with virtual columns" do
      context "TestSubclass" do
        it ".virtual_attribute_names" do
          expect(test_sub_class.virtual_attribute_names).to match_array(@vcols_sub_strs)
        end

        it ".attribute_names" do
          expect(test_sub_class.attribute_names).to match_array(@cols_sub_strs)
        end

        context ".virtual_attribute?" do
          context "with virtual column" do
            it("as string") { expect(test_sub_class.virtual_attribute?("vcolsub1")).to be_truthy }
            it("as symbol") { expect(test_sub_class.virtual_attribute?(:vcolsub1)).to  be_truthy }
          end

          context "with column" do
            it("as string") { expect(test_sub_class.virtual_attribute?("col1")).not_to be_truthy }
            it("as symbol") { expect(test_sub_class.virtual_attribute?(:col1)).not_to  be_truthy }
          end
        end

        it ".remove_virtual_fields" do
          expect(test_sub_class.remove_virtual_fields(:vcol1)).to             be_nil
          expect(test_sub_class.remove_virtual_fields(:vcolsub1)).to          be_nil
          expect(test_sub_class.remove_virtual_fields(:ref1)).to eq(:ref1)
          expect(test_sub_class.remove_virtual_fields([:vcol1])).to eq([])
          expect(test_sub_class.remove_virtual_fields([:vcolsub1])).to eq([])
          expect(test_sub_class.remove_virtual_fields([:vcolsub1, :vcol1, :ref1])).to eq([:ref1])
          expect(test_sub_class.remove_virtual_fields({:vcol1    => {}})).to eq({})
          expect(test_sub_class.remove_virtual_fields({:vcolsub1 => {}})).to eq({})
          expect(test_sub_class.remove_virtual_fields(:vcolsub1 => {}, :volsub1 => {}, :ref1 => {})).to eq({:ref1 => {}})
        end
      end
    end

    context "with virtual columns" do
      before(:each) do
        TestClass.virtual_column :vcol1, :type => :string
        TestClass.virtual_column :vcol2, :type => :string

        @vcols_strs = ["vcol1", "vcol2"]
        @vcols_syms = [:vcol1, :vcol2]
        @cols_strs  = @vcols_strs + ["id", "col1"]
        @cols_syms  = @vcols_syms + [:id, :col1]
      end

      it_should_behave_like "TestClass with virtual columns"

      context "and TestSubclass with virtual columns" do
        let(:test_sub_class) do
          Class.new(TestClass) do
            virtual_column :vcolsub1, :type => :string
          end
        end
        before(:each) do
          test_sub_class
          @vcols_sub_strs = @vcols_strs + ["vcolsub1"]
          @vcols_sub_syms = @vcols_syms + [:vcolsub1]
          @cols_sub_strs  = @vcols_sub_strs + ["id", "col1"]
          @cols_sub_syms  = @vcols_sub_syms + [:id, :col1]
        end

        it_should_behave_like "TestClass with virtual columns" # Shows inheritance doesn't pollute base class
        it_should_behave_like "TestSubclass with virtual columns"
      end
    end

    it "should not have any virtual reflections" do
      expect(TestClass.virtual_reflections).to      be_empty
      expect(TestClass.reflections_with_virtual.stringify_keys).to eq(TestClass.reflections)
      expect(TestClass.reflections_with_virtual).to eq(TestClass.reflections.symbolize_keys)
    end

    context "add_virtual_reflection integration" do
      it "with invalid parameters" do
        expect { TestClass.virtual_has_one }.to raise_error(ArgumentError)
      end

      it "with symbol name" do
        TestClass.virtual_has_one :vref1
        expect(TestClass.virtual_reflection?(:vref1)).to be_truthy
        expect(TestClass.virtual_reflection(:vref1).name).to eq(:vref1)
      end

      it("with has_one macro")    { TestClass.virtual_has_one(:vref1); expect(TestClass.virtual_reflection(:vref1).macro).to eq(:has_one) }
      it("with has_many macro")   { TestClass.virtual_has_many(:vref1); expect(TestClass.virtual_reflection(:vref1).macro).to eq(:has_many) }
      it("with belongs_to macro") { TestClass.virtual_belongs_to(:vref1); expect(TestClass.virtual_reflection(:vref1).macro).to eq(:belongs_to) }

      it "without uses" do
        TestClass.virtual_has_one :vref1
        expect(TestClass.virtual_includes(:vref1)).to be_nil
      end

      it "with uses" do
        TestClass.virtual_has_one :vref1, :uses => :ref1
        expect(TestClass.virtual_includes(:vref1)).to eq(:ref1)
      end
    end

    describe "#virtual_has_many" do
      it "use collect for virtual_ids column" do
        c = Class.new(TestClassBase) do
          self.table_name = 'test_classes'
          virtual_has_many(:hosts)
          def hosts
            [OpenStruct.new(:id => 5), OpenStruct.new(:id => 6)]
          end
        end.new

        expect(c.host_ids).to eq([5, 6])
      end

      it "use Relation#ids for virtual_ids column" do
        c = Class.new(TestClassBase) do
          self.table_name = 'test_classes'
          virtual_has_many(:hosts)
          def hosts
            OpenStruct.new(:ids => [5, 6])
          end
        end.new

        expect(c.host_ids).to eq([5, 6])
      end
    end

    %w(has_one has_many belongs_to).each do |macro|
      virtual_method = "virtual_#{macro}"

      context ".#{virtual_method}" do
        it "with symbol name" do
          TestClass.send(virtual_method, :vref1)
          expect(TestClass.virtual_reflection?(:vref1)).to be_truthy
          expect(TestClass.virtual_reflection(:vref1).name).to eq(:vref1)
        end

        it "without uses" do
          TestClass.send(virtual_method, :vref1)
          expect(TestClass.virtual_includes(:vref1)).to be_nil
        end

        it "with uses" do
          TestClass.send(virtual_method, :vref1, :uses => :ref1)
          expect(TestClass.virtual_includes(:vref1)).to eq(:ref1)
        end
      end
    end

    context "virtual_reflection assignment" do
      it "" do
        TestClass.virtual_has_one :vref1
        TestClass.virtual_has_many :vref2

        expect(TestClass.virtual_reflections.length).to eq(2)
        expect(TestClass.virtual_reflections.keys).to match_array([:vref1, :vref2])
      end

      it "with existing virtual reflections" do
        TestClass.virtual_has_one :existing_vref

        TestClass.virtual_has_one :vref1
        TestClass.virtual_has_many :vref2

        expect(TestClass.virtual_reflections.length).to eq(3)
        expect(TestClass.virtual_reflections.keys).to match_array([:existing_vref, :vref1, :vref2])
      end
    end

    shared_examples_for "TestClass with virtual reflections" do
      context "TestClass" do
        it ".virtual_reflections" do
          expect(TestClass.virtual_reflections.keys).to match_array(@vrefs_syms)
          expect(TestClass.virtual_reflections.values.collect(&:name)).to match_array(@vrefs_syms)
        end

        it ".reflections_with_virtual" do
          expect(TestClass.reflections_with_virtual.keys).to match_array(@refs_syms)
          expect(TestClass.reflections_with_virtual.values.collect(&:name)).to match_array(@refs_syms)
        end

        context ".virtual_reflection?" do
          context "with virtual reflection" do
            it("as string") { expect(TestClass.virtual_reflection?("vref1")).to be_truthy }
            it("as symbol") { expect(TestClass.virtual_reflection?(:vref1)).to  be_truthy }
          end

          context "with reflection" do
            it("as string") { expect(TestClass.virtual_reflection?("ref1")).not_to be_truthy }
            it("as symbol") { expect(TestClass.virtual_reflection?(:ref1)).not_to  be_truthy }
          end
        end

        it ".remove_virtual_fields" do
          expect(TestClass.remove_virtual_fields(:vref1)).to          be_nil
          expect(TestClass.remove_virtual_fields(:ref1)).to eq(:ref1)
          expect(TestClass.remove_virtual_fields([:vref1])).to eq([])
          expect(TestClass.remove_virtual_fields([:vref1, :ref1])).to eq([:ref1])
          expect(TestClass.remove_virtual_fields(:vref1 => {})).to eq({})
          expect(TestClass.remove_virtual_fields(:vref1 => {}, :ref1 => {})).to eq({:ref1 => {}})
        end
      end
    end

    shared_examples_for "TestSubclass with virtual reflections" do
      context "TestSubclass" do
        it ".virtual_reflections" do
          expect(test_sub_class.virtual_reflections.keys).to match_array(@vrefs_sub_syms)
          expect(test_sub_class.virtual_reflections.values.collect(&:name)).to match_array(@vrefs_sub_syms)
        end

        it ".reflections_with_virtual" do
          expect(test_sub_class.reflections_with_virtual.keys).to match_array(@refs_sub_syms)
          expect(test_sub_class.reflections_with_virtual.values.collect(&:name)).to match_array(@refs_sub_syms)
        end

        context ".virtual_reflection?" do
          context "with virtual reflection" do
            it("as string") { expect(TestClass.virtual_reflection?("vref1")).to be_truthy }
            it("as symbol") { expect(TestClass.virtual_reflection?(:vref1)).to  be_truthy }
          end

          context "with reflection" do
            it("as string") { expect(TestClass.virtual_reflection?("ref1")).not_to be_truthy }
            it("as symbol") { expect(TestClass.virtual_reflection?(:ref1)).not_to  be_truthy }
          end
        end

        it ".remove_virtual_fields" do
          expect(test_sub_class.remove_virtual_fields(:vref1)).to             be_nil
          expect(test_sub_class.remove_virtual_fields(:vrefsub1)).to          be_nil
          expect(test_sub_class.remove_virtual_fields(:ref1)).to eq(:ref1)
          expect(test_sub_class.remove_virtual_fields([:vref1])).to eq([])
          expect(test_sub_class.remove_virtual_fields([:vrefsub1])).to eq([])
          expect(test_sub_class.remove_virtual_fields([:vrefsub1, :vref1, :ref1])).to eq([:ref1])
          expect(test_sub_class.remove_virtual_fields({:vref1    => {}})).to eq({})
          expect(test_sub_class.remove_virtual_fields({:vrefsub1 => {}})).to eq({})
          expect(test_sub_class.remove_virtual_fields(:vrefsub1 => {}, :vref1 => {}, :ref1 => {})).to eq({:ref1 => {}})
        end
      end
    end

    context "with virtual reflections" do
      before(:each) do
        TestClass.virtual_has_one :vref1
        TestClass.virtual_has_one :vref2

        @vrefs_syms = [:vref1, :vref2]
        @refs_syms  = @vrefs_syms + [:ref1]
      end

      it_should_behave_like "TestClass with virtual reflections"

      context "and TestSubclass with virtual reflections" do
        let(:test_sub_class) do
          Class.new(TestClass) do
            def self.reflections; super.merge(:ref2 => OpenStruct.new(:name => :ref2, :options => {}, :klass => TestClass)); end

            virtual_has_one :vrefsub1
          end
        end
        before(:each) do
          test_sub_class
          @vrefs_sub_syms = @vrefs_syms + [:vrefsub1]
          @refs_sub_syms  = @vrefs_sub_syms + [:ref1, :ref2]
        end

        it_should_behave_like "TestClass with virtual reflections" # Shows inheritance doesn't pollute base class
        it_should_behave_like "TestSubclass with virtual reflections"
      end
    end

    context "with both virtual columns and reflections" do
      before(:each) do
        TestClass.virtual_column  :vcol1, :type => :string
        TestClass.virtual_has_one :vref1
      end

      context ".virtual_field?" do
        context "with virtual reflection" do
          it("as string") { expect(TestClass.virtual_reflection?("vref1")).to be_truthy }
          it("as symbol") { expect(TestClass.virtual_reflection?(:vref1)).to  be_truthy }
        end

        context "with reflection" do
          it("as string") { expect(TestClass.virtual_reflection?("ref1")).not_to be_truthy }
          it("as symbol") { expect(TestClass.virtual_reflection?(:ref1)).not_to  be_truthy }
        end

        context "with virtual column" do
          it("as string") { expect(TestClass.virtual_attribute?("vcol1")).to be_truthy }
          it("as symbol") { expect(TestClass.virtual_attribute?(:vcol1)).to  be_truthy }
        end

        context "with column" do
          it("as string") { expect(TestClass.virtual_attribute?("col1")).not_to be_truthy }
          it("as symbol") { expect(TestClass.virtual_attribute?(:col1)).not_to  be_truthy }
        end
      end
    end

    describe ".attribute_supported_by_sql?" do
      it "supports real columns" do
        expect(TestClass.attribute_supported_by_sql?(:col1)).to be_truthy
      end

      it "supports aliases" do
        TestClass.alias_attribute :col2, :col1

        expect(TestClass.attribute_supported_by_sql?(:col2)).to be_truthy
      end

      it "does not support virtual columns" do
        class TestClass
          virtual_attribute :col2, :integer
          def col2
            col1
          end
        end
        expect(TestClass.attribute_supported_by_sql?(:col2)).to be_falsey
      end

      it "supports virtual columns with arel" do
        class TestClass
          virtual_attribute :col2, :integer, :arel => (-> (t) { t.grouping(t.class.arel_attribute(:col1)) })
          def col2
            col1
          end
        end
        expect(TestClass.attribute_supported_by_sql?(:col2)).to be_truthy
      end

      it "supports delegates" do
        TestClass.virtual_delegate :col1, :prefix => 'parent', :to => :ref1

        expect(TestClass.attribute_supported_by_sql?(:parent_col1)).to be_truthy
      end
    end

    describe ".virtual_delegate" do
      # double purposing col1. It has an actual value in the child class
      let(:parent) { TestClass.create(:id => 1, :col1 => 4) }

      it "delegates to parent" do
        TestClass.virtual_delegate :col1, :prefix => 'parent', :to => :ref1
        tc = TestClass.new(:id => 2, :ref1 => parent)
        expect(tc.parent_col1).to eq(4)
      end

      it "delegates to nil parent" do
        TestClass.virtual_delegate :col1, :prefix => 'parent', :to => :ref1, :allow_nil => true
        tc = TestClass.new(:id => 2)
        expect(tc.parent_col1).to be_nil
      end

      it "defines parent virtual attribute" do
        TestClass.virtual_delegate :col1, :prefix => 'parent', :to => :ref1
        expect(TestClass.virtual_attribute_names).to include("parent_col1")
      end

      it "delegates to parent (sql)" do
        TestClass.virtual_delegate :col1, :prefix => 'parent', :to => :ref1
        TestClass.create(:id => 2, :ref1 => parent)
        tcs = TestClass.all.select(:id, :col1, TestClass.arel_attribute(:parent_col1).as("x"))
        expect(tcs.map(&:x)).to match_array([nil, 4])
      end
    end
  end

  describe "#follow_associations" do
    it "returns base class" do
      expect(ExtManagementSystem.follow_associations([])).to eq(ExtManagementSystem)
    end

    # Ems.has_many :vms
    # Vms.belongs_to :host
    it "follows reflections" do
      expect(ExtManagementSystem.follow_associations(%w(vms host))).to eq(Host)
    end

    # Ems.has_many :vms
    # Vms.belongs_to :host
    # Vms.virtual_has_many :processes
    it "stops at virtual reflections" do
      expect(ExtManagementSystem.follow_associations(%w(vms processes))).to be_nil
    end
  end

  describe "#follow_associations_with_virtual" do
    it "returns base class" do
      expect(ExtManagementSystem.follow_associations_with_virtual([])).to eq(ExtManagementSystem)
    end

    # Ems.has_many :vms
    # Vms.belongs_to :host
    it "follows reflections" do
      expect(ExtManagementSystem.follow_associations_with_virtual(%w(vms host))).to eq(Host)
    end

    # Ems.has_many :vms
    # Vms.belongs_to :host
    # Vms.virtual_has_many :processes
    it "follows virtual reflections" do
      expect(ExtManagementSystem.follow_associations_with_virtual(%w(vms processes))).to eq(OsProcess)
    end
  end

  describe "collect_reflections" do
    it "returns base class" do
      expect(ExtManagementSystem.collect_reflections([])).to eq([])
    end

    # Ems.has_many :vms
    # Vms.belongs_to :host
    it "follows reflections" do
      expect(ExtManagementSystem.collect_reflections(%w(vms host))).to eq([
        ExtManagementSystem.reflect_on_association(:vms), Vm.reflect_on_association(:host)
      ])
    end

    # Ems.has_many :vms
    # Vms.belongs_to :host
    # Vms.virtual_has_many :processes
    it "stops at virtual reflections" do
      expect(ExtManagementSystem.collect_reflections(%w(vms processes))).to be_nil
    end
  end

  describe "collect_reflections_with_virtual" do
    it "returns base class" do
      expect(ExtManagementSystem.collect_reflections_with_virtual([])).to eq([])
    end

    # Ems.has_many :vms
    # Vms.belongs_to :host
    it "follows reflections" do
      expect(ExtManagementSystem.collect_reflections_with_virtual(%w(vms host))).to eq([
        ExtManagementSystem.reflect_on_association(:vms), Vm.reflect_on_association(:host)
      ])
    end

    # Ems.has_many :vms
    # Vms.belongs_to :host
    # Vms.virtual_has_many :processes
    it "stops at virtual reflections" do
      expect(ExtManagementSystem.collect_reflections_with_virtual(%w(vms processes))).to eq([
        ExtManagementSystem.reflect_on_association(:vms), Vm.reflection_with_virtual(:processes)
      ])
    end
  end

  context "preloading" do
    before(:each) do
      FactoryGirl.create(:vm_vmware,
                         :hardware         => FactoryGirl.create(:hardware),
                         :operating_system => FactoryGirl.create(:operating_system),
                         :host             => FactoryGirl.create(:host,
                                                                 :hardware         => FactoryGirl.create(:hardware),
                                                                 :operating_system => FactoryGirl.create(:operating_system)
                                                                )
                        )
    end

    context "virtual column" do
      it "as Symbol" do
        expect { Vm.includes(:platform).load }.not_to raise_error
      end

      it "as Array" do
        expect { Vm.includes([:platform]).load }.not_to raise_error
        expect { Vm.includes([:platform, :host]).load }.not_to raise_error
      end

      it "as Hash" do
        expect { Vm.includes(:platform => {}).load }.not_to raise_error
        expect { Vm.includes(:platform => {}, :host => :hardware).load }.not_to raise_error
      end
    end

    context "virtual reflection" do
      it "as Symbol" do
        expect { Vm.includes(:lans).load }.not_to raise_error
      end

      it "as Array" do
        expect { Vm.includes([:lans]).load }.not_to raise_error
        expect { Vm.includes([:lans, :host]).load }.not_to raise_error
      end

      it "as Hash" do
        expect { Vm.includes(:lans => :switch).load }.not_to raise_error
        expect { Vm.includes(:lans => :switch, :host => :hardware).load }.not_to raise_error
      end
    end

    it "nested virtual fields" do
      expect { Vm.includes(:host => :ems_cluster).load }.not_to raise_error
    end

    it "virtual field that has nested virtual fields in its :uses clause" do
      expect { Vm.includes(:ems_cluster).load }.not_to raise_error
    end

    it "should handle virtual fields in :include when :conditions are also present in calculations" do
      expect { Vm.includes([:platform, :host]).references(:host).where("hosts.name = 'test'").count }.not_to raise_error
      expect { Vm.includes([:platform, :host]).references(:host).where("hosts.id IS NOT NULL").count }.not_to raise_error
    end
  end
end

describe "ApplicationRecord class" do
  describe ".virtual_attribute_names" do
    it "class immediately under ApplicationRecord" do
      result = Host.virtual_attribute_names
      expect(result).to include("region_number")
      expect(result.count("region_number")).to eq(1)
    end

    it "class not immediately under ApplicationRecord" do
      result = MiqTemplate.virtual_attribute_names
      expect(result).to include("region_number")
      expect(result.count("region_number")).to eq(1)
    end
  end

  describe ".attribute_names" do
    it "class immediately under ApplicationRecord" do
      result = ExtManagementSystem.attribute_names
      expect(result).to include("region_number")
      expect(result.count("region_number")).to eq(1)
    end

    it "class not immediately under ApplicationRecord" do
      result = EmsCloud.attribute_names
      expect(result).to include("region_number")
      expect(result.count("region_number")).to eq(1)
    end
  end
end
