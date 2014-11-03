require "spec_helper"

describe VirtualColumn do
  context ".new" do
    it("with invalid parameters") { lambda { VirtualColumn.new :vcol1 }.should raise_error(ArgumentError) }
    it("with symbol name") { VirtualColumn.new(:vcol1,  :type => :string).name.should == "vcol1" }
    it("with string name") { VirtualColumn.new("vcol1", :type => :string).name.should == "vcol1" }
  end

  context ".type" do
    it("with string type on .new")       { VirtualColumn.new(:vcol1, :type => :string).type.should      == :string }
    it("with symbol type on .new")       { VirtualColumn.new(:vcol1, :type => :symbol).type.should      == :symbol }
    it("with string_set type on .new")   { VirtualColumn.new(:vcol1, :type => :string_set).type.should  == :string_set }
    it("with numeric_type type on .new") { VirtualColumn.new(:vcol1, :type => :numeric_set).type.should == :numeric_set }
  end

  context ".klass" do
    it("with string type on .new")      { VirtualColumn.new(:vcol1, :type => :string).klass.should      == String }
    it("with symbol type on .new")      { VirtualColumn.new(:vcol1, :type => :symbol).klass.should      == Symbol }
    it("with string_set type on .new")  { VirtualColumn.new(:vcol1, :type => :string_set).klass.should  be_nil }
    it("with numeric_set type on .new") { VirtualColumn.new(:vcol1, :type => :numeric_set).klass.should be_nil }
  end

  context ".uses" do
    it("without uses on .new") { VirtualColumn.new(:vcol1, :type => :string).uses.should be_nil }
    it("with uses on .new")    { VirtualColumn.new(:vcol1, :type => :string, :uses => :col1).uses.should == :col1 }
  end

  context ".options[:uses]" do
    it("without uses on .new") { VirtualColumn.new(:vcol1, :type => :string).options[:uses].should be_nil }
    it("with uses on .new")    { VirtualColumn.new(:vcol1, :type => :string, :uses => :col1).options[:uses].should == :col1 }
  end

  it ".uses=" do
    c = VirtualColumn.new(:vcol1, :type => :string)
    c.uses = :col1
    c.uses.should           == :col1
    c.options[:uses].should == :col1
  end

  it ".options[:uses]=" do
    c =  VirtualColumn.new(:vcol1, :type => :string)
    c.options[:uses] = :col1
    c.uses.should           == :col1
    c.options[:uses].should == :col1
  end
end

describe VirtualReflection do
  before(:each) do
    require 'ostruct'
    @mock_ar = OpenStruct.new(:pluralize_table_names => false)
  end

  context ".new" do
    it("with invalid parameters") do
      lambda { VirtualReflection.new :has_one }.should raise_error(ArgumentError)
      lambda { VirtualReflection.new :vref1 }.should   raise_error(ArgumentError)
      lambda { VirtualReflection.new :has_one, :vref1, {}, nil }.should raise_error(NoMethodError) # AR object must respond_to? :pluralize_table_names
    end
    it("with symbol name") { VirtualReflection.new(:has_one, :vref1, {}, @mock_ar).name.should  == :vref1 }
    it("with string name") { VirtualReflection.new(:has_one, "vref1", {}, @mock_ar).name.should == "vref1" }
  end

  context ".class_name" do
    it("without class_name on .new") { VirtualReflection.new(:has_one, :vref1, {}, @mock_ar).class_name.should == "Vref1" }
    it("with class_name on .new")    { VirtualReflection.new(:has_one, :vref1, {:class_name => "TestClass"}, @mock_ar).class_name.should == "TestClass" }
  end

  context ".uses" do
    it("without uses on .new") { VirtualReflection.new(:has_one, :vref1, {}, @mock_ar).uses.should be_nil }
    it("with uses on .new")    { VirtualReflection.new(:has_one, :vref1, {:uses => :ref1}, @mock_ar).uses.should == :ref1 }
  end

  context ".options[:uses]" do
    it("without uses on .new") { VirtualReflection.new(:has_one, :vref1, {}, @mock_ar).options[:uses].should be_nil }
    it("with uses on .new")    { VirtualReflection.new(:has_one, :vref1, {:uses => :ref1}, @mock_ar).options[:uses].should == :ref1 }
  end

  it ".uses=" do
    c = VirtualReflection.new(:has_one, :vref1, {}, @mock_ar)
    c.uses = :ref1
    c.uses.should           == :ref1
    c.options[:uses].should == :ref1
  end

  it ".options[:uses]=" do
    c = VirtualReflection.new(:has_one, :vref1, {}, @mock_ar)
    c.options[:uses] = :ref1
    c.uses.should           == :ref1
    c.options[:uses].should == :ref1
  end
end

describe VirtualFields do
  context "TestClass" do
    before(:each) do
      class TestClassBase
        def self.pluralize_table_names; false; end
        extend VirtualFields
      end

      require 'ostruct'
      class TestClass < TestClassBase
        def self.columns_hash;         {"col1" => OpenStruct.new(:name => "col1")}; end
        def self.reflections;          {:ref1  => OpenStruct.new(:name => :ref1, :options => {}, :klass => TestClass)};  end

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
      TestClass.virtual_columns_hash.should         be_empty
      TestClass.virtual_columns.should              be_empty
      TestClass.virtual_column_names.should         be_empty
      TestClass.virtual_column_names_symbols.should be_empty

      TestClass.columns_hash_with_virtual.should         == TestClass.columns_hash
      TestClass.columns_with_virtual.should              == TestClass.columns
      TestClass.column_names_with_virtual.should         == TestClass.column_names
      TestClass.column_names_symbols_with_virtual.should == TestClass.column_names_symbols
    end

    context ".virtual_column" do
      it "with invalid parameters" do
        lambda { TestClass.virtual_column :vcol1 }.should raise_error(ArgumentError)
      end

      it "with symbol name" do
        c = TestClass.virtual_column :vcol1, :type => :string
        c.should be_kind_of(VirtualColumn)
        c.name.should == "vcol1"
      end

      it "with string name" do
        c = TestClass.virtual_column "vcol1", :type => :string
        c.should be_kind_of(VirtualColumn)
        c.name.should == "vcol1"
      end

      it "with string type" do
        c = TestClass.virtual_column :vcol1, :type => :string
        c.type.should  == :string
        c.klass.should == String
      end

      it "with symbol type" do
        c = TestClass.virtual_column :vcol1, :type => :symbol
        c.type.should  == :symbol
        c.klass.should == Symbol
      end

      it "with string_set type" do
        c = TestClass.virtual_column :vcol1, :type => :string_set
        c.type.should  == :string_set
        c.klass.should be_nil
      end

      it "with numeric_set type" do
        c = TestClass.virtual_column :vcol1, :type => :numeric_set
        c.type.should  == :numeric_set
        c.klass.should be_nil
      end

      it "without uses" do
        c = TestClass.virtual_column :vcol1, :type => :string
        c.uses.should           be_nil
        c.options[:uses].should be_nil
      end

      it "with uses" do
        c = TestClass.virtual_column :vcol1, :type => :string, :uses => :col1
        c.uses.should           == :col1
        c.options[:uses].should == :col1
      end
    end

    context ".virtual_columns=" do
      it "with invalid parameters" do
        lambda { TestClass.virtual_columns = {:vcol1 => {}} }.should raise_error(ArgumentError)
      end

      it "" do
        TestClass.virtual_columns = {
          :vcol1  => {:type => :string},
          "vcol2" => {:type => :string},
        }

        TestClass.virtual_columns_hash.length.should == 2
        TestClass.virtual_columns_hash.keys.should match_array(["vcol1", "vcol2"])
        TestClass.virtual_columns_hash.values.all? { |c| c.kind_of?(VirtualColumn) }.should be_true
      end

      it "with a VirtualColumn" do
        TestClass.virtual_columns = {
          :vcol1  => VirtualColumn.new(:vcol1,  :type => :string),
          "vcol2" => VirtualColumn.new("vcol2", :type => :string)
        }

        TestClass.virtual_columns_hash.length.should == 2
        TestClass.virtual_columns_hash.keys.should match_array(["vcol1", "vcol2"])
        TestClass.virtual_columns_hash.values.all? { |c| c.kind_of?(VirtualColumn) }.should be_true
      end

      it "with existing virtual columns" do
        TestClass.virtual_column :existing_vcol, :type => :string

        TestClass.virtual_columns = {
          :vcol1  => {:type => :string},
          "vcol2" => {:type => :string},
        }

        TestClass.virtual_columns_hash.length.should == 3
        TestClass.virtual_columns_hash.keys.should match_array(["existing_vcol", "vcol1", "vcol2"])
        TestClass.virtual_columns_hash.values.all? { |c| c.kind_of?(VirtualColumn) }.should be_true
      end
    end

    shared_examples_for "TestClass with virtual columns" do
      context "TestClass" do
        it ".virtual_columns_hash" do
          TestClass.virtual_columns_hash.keys.should match_array(@vcols_strs)
          TestClass.virtual_columns_hash.values.all? { |c| c.kind_of?(VirtualColumn) }.should be_true
          TestClass.virtual_columns_hash.values.collect(&:name).should match_array(@vcols_strs)
        end

        it ".virtual_columns" do
          TestClass.virtual_columns.all? { |c| c.kind_of?(VirtualColumn) }.should be_true
          TestClass.virtual_columns.collect(&:name).should match_array(@vcols_strs)
        end

        it ".virtual_column_names" do
          TestClass.virtual_column_names.should match_array(@vcols_strs)
        end

        it ".virtual_column_names_symbols" do
          TestClass.virtual_column_names_symbols.should match_array(@vcols_syms)
        end

        it ".columns_hash_with_virtual" do
          TestClass.columns_hash_with_virtual.keys.should match_array(@cols_strs)
          TestClass.columns_hash_with_virtual.values.collect(&:name).should match_array(@cols_strs)
        end

        it ".columns_with_virtual" do
          TestClass.columns_with_virtual.collect(&:name).should match_array(@cols_strs)
        end

        it ".column_names_with_virtual" do
          TestClass.column_names_with_virtual.should match_array(@cols_strs)
        end

        it ".column_names_symbols_with_virtual" do
          TestClass.column_names_symbols_with_virtual.should match_array(@cols_syms)
        end

        context ".virtual_column?" do
          context "with virtual column" do
            it("as string") { TestClass.virtual_column?("vcol1").should be_true }
            it("as symbol") { TestClass.virtual_column?(:vcol1).should  be_true }
          end

          context "with column" do
            it("as string") { TestClass.virtual_column?("col1").should_not be_true }
            it("as symbol") { TestClass.virtual_column?(:col1).should_not  be_true }
          end
        end

        it ".remove_virtual_fields" do
          TestClass.remove_virtual_fields(:vcol1).should          be_nil
          TestClass.remove_virtual_fields(:ref1).should           == :ref1
          TestClass.remove_virtual_fields([:vcol1]).should        == []
          TestClass.remove_virtual_fields([:vcol1, :ref1]).should == [:ref1]
          TestClass.remove_virtual_fields({:vcol1 => {}}).should  == {}
          TestClass.remove_virtual_fields({:vcol1 => {}, :ref1 => {}}).should == {:ref1 => {}}
        end
      end
    end

    shared_examples_for "TestSubclass with virtual columns" do
      context "TestSubclass" do
        it ".virtual_columns_hash" do
          TestSubclass.virtual_columns_hash.keys.should match_array(@vcols_sub_strs)
          TestSubclass.virtual_columns_hash.values.all? { |c| c.kind_of?(VirtualColumn) }.should be_true
          TestSubclass.virtual_columns_hash.values.collect(&:name).should match_array(@vcols_sub_strs)
        end

        it ".virtual_columns" do
          TestSubclass.virtual_columns.all? { |c| c.kind_of?(VirtualColumn) }.should be_true
          TestSubclass.virtual_columns.collect(&:name).should match_array(@vcols_sub_strs)
        end

        it ".virtual_column_names" do
          TestSubclass.virtual_column_names.should match_array(@vcols_sub_strs)
        end

        it ".virtual_column_names_symbols" do
          TestSubclass.virtual_column_names_symbols.should match_array(@vcols_sub_syms)
        end

        it ".columns_hash_with_virtual" do
          TestSubclass.columns_hash_with_virtual.keys.should match_array(@cols_sub_strs)
          TestSubclass.columns_hash_with_virtual.values.collect(&:name).should match_array(@cols_sub_strs)
        end

        it ".columns_with_virtual" do
          TestSubclass.columns_with_virtual.collect(&:name).should match_array(@cols_sub_strs)
        end

        it ".column_names_with_virtual" do
          TestSubclass.column_names_with_virtual.should match_array(@cols_sub_strs)
        end

        it ".column_names_symbols_with_virtual" do
          TestSubclass.column_names_symbols_with_virtual.should match_array(@cols_sub_syms)
        end

        context ".virtual_column?" do
          context "with virtual column" do
            it("as string") { TestSubclass.virtual_column?("vcolsub1").should be_true }
            it("as symbol") { TestSubclass.virtual_column?(:vcolsub1).should  be_true }
          end

          context "with column" do
            it("as string") { TestSubclass.virtual_column?("col1").should_not be_true }
            it("as symbol") { TestSubclass.virtual_column?(:col1).should_not  be_true }
          end
        end

        it ".remove_virtual_fields" do
          TestSubclass.remove_virtual_fields(:vcol1).should             be_nil
          TestSubclass.remove_virtual_fields(:vcolsub1).should          be_nil
          TestSubclass.remove_virtual_fields(:ref1).should              == :ref1
          TestSubclass.remove_virtual_fields([:vcol1]).should           == []
          TestSubclass.remove_virtual_fields([:vcolsub1]).should        == []
          TestSubclass.remove_virtual_fields([:vcolsub1, :vcol1, :ref1]).should == [:ref1]
          TestSubclass.remove_virtual_fields({:vcol1    => {}}).should  == {}
          TestSubclass.remove_virtual_fields({:vcolsub1 => {}}).should  == {}
          TestSubclass.remove_virtual_fields({:vcolsub1 => {}, :volsub1 => {}, :ref1 => {}}).should == {:ref1 => {}}
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
      TestClass.virtual_reflections.should      be_empty
      TestClass.reflections_with_virtual.should == TestClass.reflections
    end

    context ".virtual_reflection" do
      it "with invalid parameters" do
        lambda { TestClass.virtual_reflection :has_one }.should raise_error(ArgumentError)
        lambda { TestClass.virtual_reflection :vref1 }.should   raise_error(ArgumentError)
      end

      it "with symbol name" do
        c = TestClass.virtual_reflection :has_one, :vref1
        c.should be_kind_of(VirtualReflection)
        c.name.should == :vref1
      end

      it "with string name" do
        c = TestClass.virtual_reflection :has_one, "vref1"
        c.should be_kind_of(VirtualReflection)
        c.name.should == :vref1
      end

      it("with has_one macro")    { TestClass.virtual_reflection(:has_one, :vref1).macro.should    == :has_one }
      it("with has_many macro")   { TestClass.virtual_reflection(:has_many, :vref1).macro.should   == :has_many }
      it("with belongs_to macro") { TestClass.virtual_reflection(:belongs_to, :vref1).macro.should == :belongs_to }

      it "without uses" do
        c = TestClass.virtual_reflection :has_one, :vref1
        c.uses.should           be_nil
        c.options[:uses].should be_nil
      end

      it "with uses" do
        c = TestClass.virtual_reflection :has_one, :vref1, :uses => :ref1
        c.uses.should           == :ref1
        c.options[:uses].should == :ref1
      end
    end

    %w{has_one has_many belongs_to}.each do |macro|
      virtual_method = "virtual_#{macro}"

      context ".#{virtual_method}" do
        it "with symbol name" do
          c = TestClass.send(virtual_method, :vref1)
          c.should be_kind_of(VirtualReflection)
          c.name.should == :vref1
        end

        it "with string name" do
          c = TestClass.send(virtual_method, "vref1")
          c.should be_kind_of(VirtualReflection)
          c.name.should == :vref1
        end

        it "without uses" do
          c = TestClass.send(virtual_method, :vref1)
          c.uses.should           be_nil
          c.options[:uses].should be_nil
        end

        it "with uses" do
          c = TestClass.send(virtual_method, :vref1, :uses => :ref1)
          c.uses.should           == :ref1
          c.options[:uses].should == :ref1
        end
      end
    end

    context ".virtual_reflections=" do
      it "with invalid parameters" do
        lambda { TestClass.virtual_reflections = {:vref1 => {}} }.should raise_error(ArgumentError)
      end

      it "" do
        TestClass.virtual_reflections = {
          :vref1  => {:macro => :has_one},
          "vref2" => {:macro => :has_many},
        }

        TestClass.virtual_reflections.length.should == 2
        TestClass.virtual_reflections.keys.should match_array([:vref1, :vref2])
        TestClass.virtual_reflections.values.all? { |c| c.kind_of?(VirtualReflection) }.should be_true
      end

      it "with a VirtualReflection" do
        TestClass.virtual_reflections = {
          :vref1  => VirtualReflection.new(:has_one, :vref1, {}, TestClass),
          "vref2" => VirtualReflection.new(:has_one, "vref2", {}, TestClass)
        }

        TestClass.virtual_reflections.length.should == 2
        TestClass.virtual_reflections.keys.should match_array([:vref1, :vref2])
        TestClass.virtual_reflections.values.all? { |c| c.kind_of?(VirtualReflection) }.should be_true
      end

      it "with existing virtual reflections" do
        TestClass.virtual_has_one :existing_vref

        TestClass.virtual_reflections = {
          :vref1  => {:macro => :has_one},
          "vref2" => {:macro => :has_many},
        }

        TestClass.virtual_reflections.length.should == 3
        TestClass.virtual_reflections.keys.should match_array([:existing_vref, :vref1, :vref2])
        TestClass.virtual_reflections.values.all? { |c| c.kind_of?(VirtualReflection) }.should be_true
      end
    end

    shared_examples_for "TestClass with virtual reflections" do
      context "TestClass" do
        it ".virtual_reflections" do
          TestClass.virtual_reflections.keys.should match_array(@vrefs_syms)
          TestClass.virtual_reflections.values.all? { |c| c.kind_of?(VirtualReflection) }.should be_true
          TestClass.virtual_reflections.values.collect(&:name).should match_array(@vrefs_syms)
        end

        it ".reflections_with_virtual" do
          TestClass.reflections_with_virtual.keys.should match_array(@refs_syms)
          TestClass.reflections_with_virtual.values.collect(&:name).should match_array(@refs_syms)
        end

        context ".virtual_reflection?" do
          context "with virtual reflection" do
            it("as string") { TestClass.virtual_reflection?("vref1").should be_true }
            it("as symbol") { TestClass.virtual_reflection?(:vref1).should  be_true }
          end

          context "with reflection" do
            it("as string") { TestClass.virtual_reflection?("ref1").should_not be_true }
            it("as symbol") { TestClass.virtual_reflection?(:ref1).should_not  be_true }
          end
        end

        it ".remove_virtual_fields" do
          TestClass.remove_virtual_fields(:vref1).should          be_nil
          TestClass.remove_virtual_fields(:ref1).should           == :ref1
          TestClass.remove_virtual_fields([:vref1]).should        == []
          TestClass.remove_virtual_fields([:vref1, :ref1]).should == [:ref1]
          TestClass.remove_virtual_fields({:vref1 => {}}).should  == {}
          TestClass.remove_virtual_fields({:vref1 => {}, :ref1 => {}}).should == {:ref1 => {}}
        end
      end
    end

    shared_examples_for "TestSubclass with virtual reflections" do
      context "TestSubclass" do
        it ".virtual_reflections" do
          TestSubclass.virtual_reflections.keys.should match_array(@vrefs_sub_syms)
          TestSubclass.virtual_reflections.values.all? { |c| c.kind_of?(VirtualReflection) }.should be_true
          TestSubclass.virtual_reflections.values.collect(&:name).should match_array(@vrefs_sub_syms)
        end

        it ".reflections_with_virtual" do
          TestSubclass.reflections_with_virtual.keys.should match_array(@refs_sub_syms)
          TestSubclass.reflections_with_virtual.values.collect(&:name).should match_array(@refs_sub_syms)
        end

        context ".virtual_reflection?" do
          context "with virtual reflection" do
            it("as string") { TestClass.virtual_reflection?("vref1").should be_true }
            it("as symbol") { TestClass.virtual_reflection?(:vref1).should  be_true }
          end

          context "with reflection" do
            it("as string") { TestClass.virtual_reflection?("ref1").should_not be_true }
            it("as symbol") { TestClass.virtual_reflection?(:ref1).should_not  be_true }
          end
        end

        it ".remove_virtual_fields" do
          TestSubclass.remove_virtual_fields(:vref1).should             be_nil
          TestSubclass.remove_virtual_fields(:vrefsub1).should          be_nil
          TestSubclass.remove_virtual_fields(:ref1).should              == :ref1
          TestSubclass.remove_virtual_fields([:vref1]).should           == []
          TestSubclass.remove_virtual_fields([:vrefsub1]).should        == []
          TestSubclass.remove_virtual_fields([:vrefsub1, :vref1, :ref1]).should == [:ref1]
          TestSubclass.remove_virtual_fields({:vref1    => {}}).should  == {}
          TestSubclass.remove_virtual_fields({:vrefsub1 => {}}).should  == {}
          TestSubclass.remove_virtual_fields({:vrefsub1 => {}, :vref1 => {}, :ref1 => {}}).should == {:ref1 => {}}
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
          it("as string") { TestClass.virtual_reflection?("vref1").should be_true }
          it("as symbol") { TestClass.virtual_reflection?(:vref1).should  be_true }
        end

        context "with reflection" do
          it("as string") { TestClass.virtual_reflection?("ref1").should_not be_true }
          it("as symbol") { TestClass.virtual_reflection?(:ref1).should_not  be_true }
        end

        context "with virtual column" do
          it("as string") { TestClass.virtual_column?("vcol1").should be_true }
          it("as symbol") { TestClass.virtual_column?(:vcol1).should  be_true }
        end

        context "with column" do
          it("as string") { TestClass.virtual_column?("col1").should_not be_true }
          it("as symbol") { TestClass.virtual_column?(:col1).should_not  be_true }
        end
      end
    end
  end

  context "preloading" do
    before(:each) do
      FactoryGirl.create(:vm_vmware,
        :hardware         => FactoryGirl.create(:hardware),
        :operating_system => FactoryGirl.create(:operating_system),
        :host => FactoryGirl.create(:host,
          :hardware         => FactoryGirl.create(:hardware),
          :operating_system => FactoryGirl.create(:operating_system)
        )
      )
    end

    context "virtual column" do
      it "as Symbol" do
        lambda { Vm.all(:include => :platform) }.should_not raise_error
      end

      it "as Array" do
        lambda { Vm.all(:include => [:platform]) }.should_not raise_error
        lambda { Vm.all(:include => [:platform, :host]) }.should_not raise_error
      end

      it "as Hash" do
        lambda { Vm.all(:include => {:platform => {}}) }.should_not raise_error
        lambda { Vm.all(:include => {:platform => {}, :host => :hardware}) }.should_not raise_error
      end
    end

    context "virtual reflection" do
      it "as Symbol" do
        lambda { Vm.all(:include => :lans) }.should_not raise_error
      end

      it "as Array" do
        lambda { Vm.all(:include => [:lans]) }.should_not raise_error
        lambda { Vm.all(:include => [:lans, :host]) }.should_not raise_error
      end

      it "as Hash" do
        lambda { Vm.all(:include => {:lans => :switch}) }.should_not raise_error
        lambda { Vm.all(:include => {:lans => :switch, :host => :hardware}) }.should_not raise_error
      end
    end

    it "nested virtual fields" do
      lambda { Vm.all(:include => {:host => :ems_cluster}) }.should_not raise_error
    end

    it "virtual field that has nested virtual fields in its :uses clause" do
      lambda { Vm.all(:include => :ems_cluster) }.should_not raise_error
    end

    it "virtual fields as Hash when :conditions are also present" do
      lambda { Vm.all(:include => [:platform, :host], :conditions => "hosts.name = 'test'") }.should_not raise_error
      lambda { Vm.all(:include => [:platform, :host], :conditions => "hosts.id IS NOT NULL") }.should_not raise_error
    end

    it "should handle virtual fields in :include when :conditions are also present in calculations" do
      lambda { Vm.count(:include => [:platform, :host], :conditions => "hosts.name = 'test'") }.should_not raise_error
      lambda { Vm.count(:include => [:platform, :host], :conditions => "hosts.id IS NOT NULL") }.should_not raise_error
    end
  end
end
