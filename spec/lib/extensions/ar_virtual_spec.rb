require "spec_helper"

describe VirtualColumn do
  context ".new" do
    it("with invalid parameters") { expect { VirtualColumn.new :vcol1 }.to raise_error(ArgumentError) }
    it("with symbol name") { expect(VirtualColumn.new(:vcol1,  :type => :string).name).to eq("vcol1") }
    it("with string name") { expect(VirtualColumn.new("vcol1", :type => :string).name).to eq("vcol1") }
  end

  context ".type" do
    it("with string type on .new")       { expect(VirtualColumn.new(:vcol1, :type => :string).type).to eq(:string) }
    it("with symbol type on .new")       { expect(VirtualColumn.new(:vcol1, :type => :symbol).type).to eq(:symbol) }
    it("with string_set type on .new")   { expect(VirtualColumn.new(:vcol1, :type => :string_set).type).to eq(:string_set) }
    it("with numeric_type type on .new") { expect(VirtualColumn.new(:vcol1, :type => :numeric_set).type).to eq(:numeric_set) }
  end

  context ".klass" do
    it("with string type on .new")      { expect(VirtualColumn.new(:vcol1, :type => :string).klass).to eq(String) }
    it("with symbol type on .new")      { expect(VirtualColumn.new(:vcol1, :type => :symbol).klass).to eq(Symbol) }
    it("with string_set type on .new")  { expect(VirtualColumn.new(:vcol1, :type => :string_set).klass).to  be_nil }
    it("with numeric_set type on .new") { expect(VirtualColumn.new(:vcol1, :type => :numeric_set).klass).to be_nil }
  end

  context ".uses" do
    it("without uses on .new") { expect(VirtualColumn.new(:vcol1, :type => :string).uses).to be_nil }
    it("with uses on .new")    { expect(VirtualColumn.new(:vcol1, :type => :string, :uses => :col1).uses).to eq(:col1) }
  end

  context ".options[:uses]" do
    it("without uses on .new") { expect(VirtualColumn.new(:vcol1, :type => :string).options[:uses]).to be_nil }
    it("with uses on .new")    { expect(VirtualColumn.new(:vcol1, :type => :string, :uses => :col1).options[:uses]).to eq(:col1) }
  end

  it ".uses=" do
    c = VirtualColumn.new(:vcol1, :type => :string)
    c.uses = :col1
    expect(c.uses).to eq(:col1)
    expect(c.options[:uses]).to eq(:col1)
  end

  it ".options[:uses]=" do
    c =  VirtualColumn.new(:vcol1, :type => :string)
    c.options[:uses] = :col1
    expect(c.uses).to eq(:col1)
    expect(c.options[:uses]).to eq(:col1)
  end
end

describe VirtualReflection do
  before(:each) do
    require 'ostruct'
    @mock_ar = OpenStruct.new(:pluralize_table_names => false)
  end

  def model_with_virtual_fields(&block)
    Class.new(ActiveRecord::Base) do
      extend VirtualFields
      class_eval(&block)
    end
  end

  context ".new" do
    it("with symbol name") do
      klass = model_with_virtual_fields { virtual_has_one :vref1 }
      reflection = klass.virtual_field(:vref1)
      expect(reflection.name).to eq(:vref1)
    end
  end

  context ".class_name" do
    it("without class_name on .new") do
      klass = model_with_virtual_fields { virtual_has_one :vref1 }
      reflection = klass.virtual_field(:vref1)
      expect(reflection.class_name).to eq("Vref1")
    end
    it("with class_name on .new") do
      klass = model_with_virtual_fields do
        virtual_has_one :vref1, :class_name => "TestClass"
      end
      reflection = klass.virtual_field(:vref1)
      expect(reflection.class_name).to eq("TestClass")
    end
  end

  context ".uses" do
    it("without uses on .new") do
      klass = model_with_virtual_fields { virtual_has_one :vref1 }
      reflection = klass.virtual_field(:vref1)
      expect(reflection.uses).to be_nil
    end
    it("with uses on .new") do
      klass = model_with_virtual_fields do
        virtual_has_one :vref1, :uses => :ref1
      end
      reflection = klass.virtual_field(:vref1)
      expect(reflection.uses).to eq(:ref1)
    end
  end

  it ".uses=" do
    c = model_with_virtual_fields { virtual_has_one :vref1 }.virtual_field(:vref1)
    c.uses = :ref1
    expect(c.uses).to eq(:ref1)
  end

  it ".options[:uses]=" do
    c = model_with_virtual_fields { virtual_has_one :vref1 }.virtual_field(:vref1)
    c.options[:uses] = :ref1
    expect(c.options[:uses]).to eq(:ref1)
  end
end

describe VirtualFields do
  context "TestClass" do
    before(:each) do
      class TestClassBase
        def self.pluralize_table_names; false; end

        # HACK: Simulate a real model by defining some methods expected by
        # ActiveRecord::Associations::Builder::Association.build
        def self.dangerous_attribute_method?(_); false; end

        def self.generated_association_methods(*_args); []; end

        def self.add_autosave_association_callbacks(*_args); end
        extend VirtualFields
      end

      require 'ostruct'
      class TestClass < TestClassBase
        def self.columns_hash;         {"col1" => OpenStruct.new(:name => "col1")}; end

        def self.reflections;          {:ref1  => OpenStruct.new(:name => :ref1, :options => {}, :klass => TestClass)};  end

        def self.reflect_on_association(name); reflections[name]; end

        def self.columns;              columns_hash.values; end

        def self.column_names;         ["col1"]; end

        def self.column_names_symbols; [:col1];  end
      end
    end

    after(:each) do
      Object.send(:remove_const, :TestClass)
      Object.send(:remove_const, :TestClassBase)
    end

    it "should not have any virtual columns" do
      expect(TestClass.virtual_columns_hash).to         be_empty
      expect(TestClass.virtual_columns).to              be_empty
      expect(TestClass.virtual_column_names).to         be_empty
      expect(TestClass.virtual_column_names_symbols).to be_empty

      expect(TestClass.columns_hash_with_virtual).to eq(TestClass.columns_hash)
      expect(TestClass.columns_with_virtual).to eq(TestClass.columns)
      expect(TestClass.column_names_with_virtual).to eq(TestClass.column_names)
      expect(TestClass.column_names_symbols_with_virtual).to eq(TestClass.column_names_symbols)
    end

    context ".virtual_column" do
      it "with invalid parameters" do
        expect { TestClass.virtual_column :vcol1 }.to raise_error(ArgumentError)
      end

      it "with symbol name" do
        c = TestClass.virtual_column :vcol1, :type => :string
        expect(c).to be_kind_of(VirtualColumn)
        expect(c.name).to eq("vcol1")
      end

      it "with string name" do
        c = TestClass.virtual_column "vcol1", :type => :string
        expect(c).to be_kind_of(VirtualColumn)
        expect(c.name).to eq("vcol1")
      end

      it "with string type" do
        c = TestClass.virtual_column :vcol1, :type => :string
        expect(c.type).to eq(:string)
        expect(c.klass).to eq(String)
      end

      it "with symbol type" do
        c = TestClass.virtual_column :vcol1, :type => :symbol
        expect(c.type).to eq(:symbol)
        expect(c.klass).to eq(Symbol)
      end

      it "with string_set type" do
        c = TestClass.virtual_column :vcol1, :type => :string_set
        expect(c.type).to eq(:string_set)
        expect(c.klass).to be_nil
      end

      it "with numeric_set type" do
        c = TestClass.virtual_column :vcol1, :type => :numeric_set
        expect(c.type).to eq(:numeric_set)
        expect(c.klass).to be_nil
      end

      it "without uses" do
        c = TestClass.virtual_column :vcol1, :type => :string
        expect(c.uses).to           be_nil
        expect(c.options[:uses]).to be_nil
      end

      it "with uses" do
        c = TestClass.virtual_column :vcol1, :type => :string, :uses => :col1
        expect(c.uses).to eq(:col1)
        expect(c.options[:uses]).to eq(:col1)
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

        expect(TestClass.virtual_columns_hash.length).to eq(2)
        expect(TestClass.virtual_columns_hash.keys).to match_array(["vcol1", "vcol2"])
        expect(TestClass.virtual_columns_hash.values.all? { |c| c.kind_of?(VirtualColumn) }).to be_truthy
      end

      it "with existing virtual columns" do
        TestClass.virtual_column :existing_vcol, :type => :string

        {
          :vcol1  => {:type => :string},
          "vcol2" => {:type => :string},
        }.each do |name, options|
          TestClass.virtual_column name, options
        end

        expect(TestClass.virtual_columns_hash.length).to eq(3)
        expect(TestClass.virtual_columns_hash.keys).to match_array(["existing_vcol", "vcol1", "vcol2"])
        expect(TestClass.virtual_columns_hash.values.all? { |c| c.kind_of?(VirtualColumn) }).to be_truthy
      end
    end

    shared_examples_for "TestClass with virtual columns" do
      context "TestClass" do
        it ".virtual_columns_hash" do
          expect(TestClass.virtual_columns_hash.keys).to match_array(@vcols_strs)
          expect(TestClass.virtual_columns_hash.values.all? { |c| c.kind_of?(VirtualColumn) }).to be_truthy
          expect(TestClass.virtual_columns_hash.values.collect(&:name)).to match_array(@vcols_strs)
        end

        it ".virtual_columns" do
          expect(TestClass.virtual_columns.all? { |c| c.kind_of?(VirtualColumn) }).to be_truthy
          expect(TestClass.virtual_columns.collect(&:name)).to match_array(@vcols_strs)
        end

        it ".virtual_column_names" do
          expect(TestClass.virtual_column_names).to match_array(@vcols_strs)
        end

        it ".virtual_column_names_symbols" do
          expect(TestClass.virtual_column_names_symbols).to match_array(@vcols_syms)
        end

        it ".columns_hash_with_virtual" do
          expect(TestClass.columns_hash_with_virtual.keys).to match_array(@cols_strs)
          expect(TestClass.columns_hash_with_virtual.values.collect(&:name)).to match_array(@cols_strs)
        end

        it ".columns_with_virtual" do
          expect(TestClass.columns_with_virtual.collect(&:name)).to match_array(@cols_strs)
        end

        it ".column_names_with_virtual" do
          expect(TestClass.column_names_with_virtual).to match_array(@cols_strs)
        end

        it ".column_names_symbols_with_virtual" do
          expect(TestClass.column_names_symbols_with_virtual).to match_array(@cols_syms)
        end

        context ".virtual_column?" do
          context "with virtual column" do
            it("as string") { expect(TestClass.virtual_column?("vcol1")).to be_truthy }
            it("as symbol") { expect(TestClass.virtual_column?(:vcol1)).to  be_truthy }
          end

          context "with column" do
            it("as string") { expect(TestClass.virtual_column?("col1")).not_to be_truthy }
            it("as symbol") { expect(TestClass.virtual_column?(:col1)).not_to  be_truthy }
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
        it ".virtual_columns_hash" do
          expect(TestSubclass.virtual_columns_hash.keys).to match_array(@vcols_sub_strs)
          expect(TestSubclass.virtual_columns_hash.values.all? { |c| c.kind_of?(VirtualColumn) }).to be_truthy
          expect(TestSubclass.virtual_columns_hash.values.collect(&:name)).to match_array(@vcols_sub_strs)
        end

        it ".virtual_columns" do
          expect(TestSubclass.virtual_columns.all? { |c| c.kind_of?(VirtualColumn) }).to be_truthy
          expect(TestSubclass.virtual_columns.collect(&:name)).to match_array(@vcols_sub_strs)
        end

        it ".virtual_column_names" do
          expect(TestSubclass.virtual_column_names).to match_array(@vcols_sub_strs)
        end

        it ".virtual_column_names_symbols" do
          expect(TestSubclass.virtual_column_names_symbols).to match_array(@vcols_sub_syms)
        end

        it ".columns_hash_with_virtual" do
          expect(TestSubclass.columns_hash_with_virtual.keys).to match_array(@cols_sub_strs)
          expect(TestSubclass.columns_hash_with_virtual.values.collect(&:name)).to match_array(@cols_sub_strs)
        end

        it ".columns_with_virtual" do
          expect(TestSubclass.columns_with_virtual.collect(&:name)).to match_array(@cols_sub_strs)
        end

        it ".column_names_with_virtual" do
          expect(TestSubclass.column_names_with_virtual).to match_array(@cols_sub_strs)
        end

        it ".column_names_symbols_with_virtual" do
          expect(TestSubclass.column_names_symbols_with_virtual).to match_array(@cols_sub_syms)
        end

        context ".virtual_column?" do
          context "with virtual column" do
            it("as string") { expect(TestSubclass.virtual_column?("vcolsub1")).to be_truthy }
            it("as symbol") { expect(TestSubclass.virtual_column?(:vcolsub1)).to  be_truthy }
          end

          context "with column" do
            it("as string") { expect(TestSubclass.virtual_column?("col1")).not_to be_truthy }
            it("as symbol") { expect(TestSubclass.virtual_column?(:col1)).not_to  be_truthy }
          end
        end

        it ".remove_virtual_fields" do
          expect(TestSubclass.remove_virtual_fields(:vcol1)).to             be_nil
          expect(TestSubclass.remove_virtual_fields(:vcolsub1)).to          be_nil
          expect(TestSubclass.remove_virtual_fields(:ref1)).to eq(:ref1)
          expect(TestSubclass.remove_virtual_fields([:vcol1])).to eq([])
          expect(TestSubclass.remove_virtual_fields([:vcolsub1])).to eq([])
          expect(TestSubclass.remove_virtual_fields([:vcolsub1, :vcol1, :ref1])).to eq([:ref1])
          expect(TestSubclass.remove_virtual_fields({:vcol1    => {}})).to eq({})
          expect(TestSubclass.remove_virtual_fields({:vcolsub1 => {}})).to eq({})
          expect(TestSubclass.remove_virtual_fields(:vcolsub1 => {}, :volsub1 => {}, :ref1 => {})).to eq({:ref1 => {}})
        end
      end
    end

    context "with virtual columns" do
      before(:each) do
        TestClass.virtual_column :vcol1, :type => :string
        TestClass.virtual_column :vcol2, :type => :string

        @vcols_strs = ["vcol1", "vcol2"]
        @vcols_syms = [:vcol1, :vcol2]
        @cols_strs  = @vcols_strs + ["col1"]
        @cols_syms  = @vcols_syms + [:col1]
      end

      it_should_behave_like "TestClass with virtual columns"

      context "and TestSubclass with virtual columns" do
        before(:each) do
          class TestSubclass < TestClass
            virtual_column :vcolsub1, :type => :string
          end

          @vcols_sub_strs = @vcols_strs + ["vcolsub1"]
          @vcols_sub_syms = @vcols_syms + [:vcolsub1]
          @cols_sub_strs  = @vcols_sub_strs + ["col1"]
          @cols_sub_syms  = @vcols_sub_syms + [:col1]
        end

        after(:each) do
          Object.send(:remove_const, :TestSubclass)
        end

        it_should_behave_like "TestClass with virtual columns" # Shows inheritance doesn't pollute base class
        it_should_behave_like "TestSubclass with virtual columns"
      end
    end

    it "should not have any virtual reflections" do
      expect(TestClass.virtual_reflections).to      be_empty
      expect(TestClass.reflections_with_virtual).to eq(TestClass.reflections)
    end

    context "add_virtual_reflection integration" do
      it "with invalid parameters" do
        expect { TestClass.virtual_has_one }.to raise_error(ArgumentError)
      end

      it "with symbol name" do
        c = TestClass.virtual_has_one :vref1
        expect(c).to be_kind_of(VirtualReflection)
        expect(c.name).to eq(:vref1)
      end

      it("with has_one macro")    { expect(TestClass.virtual_has_one(:vref1).macro).to eq(:has_one) }
      it("with has_many macro")   { expect(TestClass.virtual_has_many(:vref1).macro).to eq(:has_many) }
      it("with belongs_to macro") { expect(TestClass.virtual_belongs_to(:vref1).macro).to eq(:belongs_to) }

      it "without uses" do
        c = TestClass.virtual_has_one :vref1
        expect(c.uses).to           be_nil
        expect(c.options[:uses]).to be_nil
      end

      it "with uses" do
        c = TestClass.virtual_has_one :vref1, :uses => :ref1
        expect(c.uses).to eq(:ref1)
      end
    end

    describe "#virtual_has_many" do
      it "use collect for virtual_ids column" do
        c = Class.new(TestClassBase) do
          virtual_has_many(:hosts)
          def hosts
            [OpenStruct.new(:id => 5), OpenStruct.new(:id => 6)]
          end
        end.new

        expect(c.host_ids).to eq([5, 6])
      end

      it "use Relation#ids for virtual_ids column" do
        c = Class.new(TestClassBase) do
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
          c = TestClass.send(virtual_method, :vref1)
          expect(c).to be_kind_of(VirtualReflection)
          expect(c.name).to eq(:vref1)
        end

        it "without uses" do
          c = TestClass.send(virtual_method, :vref1)
          expect(c.uses).to           be_nil
        end

        it "with uses" do
          c = TestClass.send(virtual_method, :vref1, :uses => :ref1)
          expect(c.uses).to eq(:ref1)
        end
      end
    end

    context "virtual_reflection assignment" do
      it "" do
        {
          :vref1 => {:macro => :has_one},
          :vref2 => {:macro => :has_many},
        }.each do |name, options|
          TestClass.send "virtual_#{options[:macro]}", name
        end

        expect(TestClass.virtual_reflections.length).to eq(2)
        expect(TestClass.virtual_reflections.keys).to match_array([:vref1, :vref2])
        expect(TestClass.virtual_reflections.values.all? { |c| c.kind_of?(VirtualReflection) }).to be_truthy
      end

      it "with existing virtual reflections" do
        TestClass.virtual_has_one :existing_vref

        {
          :vref1 => {:macro => :has_one},
          :vref2 => {:macro => :has_many},
        }.each do |name, options|
          TestClass.send "virtual_#{options[:macro]}", name
        end

        expect(TestClass.virtual_reflections.length).to eq(3)
        expect(TestClass.virtual_reflections.keys).to match_array([:existing_vref, :vref1, :vref2])
        expect(TestClass.virtual_reflections.values.all? { |c| c.kind_of?(VirtualReflection) }).to be_truthy
      end
    end

    shared_examples_for "TestClass with virtual reflections" do
      context "TestClass" do
        it ".virtual_reflections" do
          expect(TestClass.virtual_reflections.keys).to match_array(@vrefs_syms)
          expect(TestClass.virtual_reflections.values.all? { |c| c.kind_of?(VirtualReflection) }).to be_truthy
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
          expect(TestSubclass.virtual_reflections.keys).to match_array(@vrefs_sub_syms)
          expect(TestSubclass.virtual_reflections.values.all? { |c| c.kind_of?(VirtualReflection) }).to be_truthy
          expect(TestSubclass.virtual_reflections.values.collect(&:name)).to match_array(@vrefs_sub_syms)
        end

        it ".reflections_with_virtual" do
          expect(TestSubclass.reflections_with_virtual.keys).to match_array(@refs_sub_syms)
          expect(TestSubclass.reflections_with_virtual.values.collect(&:name)).to match_array(@refs_sub_syms)
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
          expect(TestSubclass.remove_virtual_fields(:vref1)).to             be_nil
          expect(TestSubclass.remove_virtual_fields(:vrefsub1)).to          be_nil
          expect(TestSubclass.remove_virtual_fields(:ref1)).to eq(:ref1)
          expect(TestSubclass.remove_virtual_fields([:vref1])).to eq([])
          expect(TestSubclass.remove_virtual_fields([:vrefsub1])).to eq([])
          expect(TestSubclass.remove_virtual_fields([:vrefsub1, :vref1, :ref1])).to eq([:ref1])
          expect(TestSubclass.remove_virtual_fields({:vref1    => {}})).to eq({})
          expect(TestSubclass.remove_virtual_fields({:vrefsub1 => {}})).to eq({})
          expect(TestSubclass.remove_virtual_fields(:vrefsub1 => {}, :vref1 => {}, :ref1 => {})).to eq({:ref1 => {}})
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
        before(:each) do
          class TestSubclass < TestClass
            def self.reflections; super.merge(:ref2 => OpenStruct.new(:name => :ref2, :options => {}, :klass => TestClass)); end

            virtual_has_one :vrefsub1
          end

          @vrefs_sub_syms = @vrefs_syms + [:vrefsub1]
          @refs_sub_syms  = @vrefs_sub_syms + [:ref1, :ref2]
        end

        after(:each) do
          Object.send(:remove_const, :TestSubclass)
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
          it("as string") { expect(TestClass.virtual_column?("vcol1")).to be_truthy }
          it("as symbol") { expect(TestClass.virtual_column?(:vcol1)).to  be_truthy }
        end

        context "with column" do
          it("as string") { expect(TestClass.virtual_column?("col1")).not_to be_truthy }
          it("as symbol") { expect(TestClass.virtual_column?(:col1)).not_to  be_truthy }
        end
      end
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

describe "ActiveRecord::Base class" do
  context "class immediately under ActiveRecord::Base" do
    it ".virtual_column_names" do
      result = Host.virtual_column_names
      expect(result.count("region_number")).to eq(1)
    end

    it ".column_names_with_virtual" do
      result = ExtManagementSystem.column_names_with_virtual
      expect(result.count("region_number")).to eq(1)
    end
  end

  context "class not immediately under ActiveRecord::Base" do
    it ".virtual_column_names" do
      result = MiqTemplate.virtual_column_names
      expect(result.count("region_number")).to eq(1)
    end

    it ".column_names_with_virtual" do
      result = EmsCloud.column_names_with_virtual
      expect(result.count("region_number")).to eq(1)
    end
  end
end
