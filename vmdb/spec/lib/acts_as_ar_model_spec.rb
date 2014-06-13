require "spec_helper"

describe ActsAsArModel do
  before(:each) do
    class TestClass1 < ActsAsArModel
      set_columns_hash(
        :str => :string,
        :int => :integer,
        :flt => :float,
        :dt  => :datetime,
        :str_with_options => {:type => :string, :some_opt => 'opt_value'}
      )
    end

    # id is a default column included regardless if it's in the set_columns_hash
    @col_names_syms = [:str, :id, :int, :flt, :dt, :str_with_options]
    @col_names_strs = ["str", "id", "int", "flt", "dt", "str_with_options"]
  end

  after(:each) do
    Object.send(:remove_const, :TestClass1)
  end

  describe "subclass, TestClass1," do
    it(".base_class") { TestClass1.base_class.should == TestClass1 }
    it(".base_model") { TestClass1.base_model.should == TestClass1 }

    it { TestClass1.should respond_to(:columns_hash) }
    it { TestClass1.should respond_to(:columns) }
    it { TestClass1.should respond_to(:column_names) }
    it { TestClass1.should respond_to(:column_names_symbols) }

    it { TestClass1.should respond_to(:virtual_columns) }

    it { TestClass1.should respond_to(:aar_columns) }

    it { TestClass1.columns_hash.values[0].should be_kind_of(ActsAsArModelColumn) }
    it { TestClass1.columns_hash.keys.should      have_same_elements(@col_names_strs) }
    it { TestClass1.column_names.should           have_same_elements(@col_names_strs) }
    it { TestClass1.column_names_symbols.should   have_same_elements(@col_names_syms) }

    it { TestClass1.columns_hash["str_with_options"].options[:some_opt].should == 'opt_value' }

    describe "instance" do
      it { TestClass1.new.should respond_to(:attributes) }
      it { TestClass1.new.should respond_to(:str) }

      it "should allow attribute initialization" do
        t = TestClass1.new(:str => "test_value")
        t.str.should == "test_value"
      end

      it "should allow attribute access" do
        t = TestClass1.new
        t.str.should be_nil

        t.str = "test_value"
        t.str.should == "test_value"
      end
    end

    describe "subclass, TestSubClass1," do
      before(:each) { class TestSubClass1 < TestClass1; end }
      after(:each)  { Object.send(:remove_const, :TestSubClass1) }

      it(".base_class") { TestSubClass1.base_class.should == TestClass1 }
      it(".base_model") { TestSubClass1.base_model.should == TestClass1 }
    end
  end

  describe "subclass, TestClass2," do
    before(:each) { class TestClass2 < ActsAsArModel; end }
    after(:each)  { Object.send(:remove_const, :TestClass2) }

    it(".base_class") { TestClass2.base_class.should == TestClass2 }
    it(".base_model") { TestClass2.base_model.should == TestClass2 }

    it { TestClass2.columns_hash.should be_empty }
  end
end
