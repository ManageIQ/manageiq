require "spec_helper"

describe ActsAsArModel do
  before { base_class }

  # id is a default column included regardless if it's in the set_columns_hash
  let(:col_names_syms) { [:str, :id, :int, :flt, :dt, :str_with_options] }
  let(:col_names_strs) { %w(str id int flt dt str_with_options) }

  let(:base_class) do
    Class.new(ActsAsArModel) do
      set_columns_hash(
        :str              => :string,
        :int              => :integer,
        :flt              => :float,
        :dt               => :datetime,
        :str_with_options => {:type => :string, :some_opt => 'opt_value'}
      )
    end
  end

  describe "subclass, base_class," do
    it(".base_class") { base_class.base_class.should == base_class }
    it(".base_model") { base_class.base_model.should == base_class }

    it { base_class.should respond_to(:columns_hash) }
    it { base_class.should respond_to(:columns) }
    it { base_class.should respond_to(:column_names) }
    it { base_class.should respond_to(:column_names_symbols) }

    it { base_class.should respond_to(:virtual_columns) }

    it { base_class.should respond_to(:aar_columns) }

    it { base_class.columns_hash.values[0].should be_kind_of(ActsAsArModelColumn) }
    it { base_class.columns_hash.keys.should      match_array(col_names_strs) }
    it { base_class.column_names.should           match_array(col_names_strs) }
    it { base_class.column_names_symbols.should   match_array(col_names_syms) }

    it { base_class.columns_hash["str_with_options"].options[:some_opt].should == 'opt_value' }

    describe "instance" do
      it { base_class.new.should respond_to(:attributes) }
      it { base_class.new.should respond_to(:str) }

      it "should allow attribute initialization" do
        t = base_class.new(:str => "test_value")
        t.str.should == "test_value"
      end

      it "should allow attribute access" do
        t = base_class.new
        t.str.should be_nil

        t.str = "test_value"
        t.str.should == "test_value"
      end
    end

    describe "subclass, TestSubClass1," do
      let(:sub_class) { Class.new(base_class) }

      it(".base_class") { sub_class.base_class.should == base_class }
      it(".base_model") { sub_class.base_model.should == base_class }
    end
  end

  describe "subclass, TestClass2," do
    let(:sub_class) { Class.new(ActsAsArModel) }

    it(".base_class") { sub_class.base_class.should == sub_class }
    it(".base_model") { sub_class.base_model.should == sub_class }

    it { sub_class.columns_hash.should be_empty }
  end

  context "AR backed model" do
    # model contains ids of important vms - acts like ar model
    let(:important_vm_model) do
      Class.new(ActsAsArModel) do
        def self.vm_ids
          @vm_ids ||= []
        end

        def self.vm_ids=(new_ids)
          @vm_ids = new_ids
        end

        def self.aar_scope
          Vm.where(:id => vm_ids)
        end
      end
    end

    it ".all" do
      good = FactoryGirl.create_list(:vm, 3)
      bad = FactoryGirl.create_list(:vm, 1)

      important_vm_model.vm_ids += good.map(&:id)

      expect(important_vm_model.all.order(:id)).to eq(good)
      expect(important_vm_model.all.order('id desc').first).to eq(good.last)
      expect(important_vm_model.first).to eq(good.first)
      expect(important_vm_model.last).to eq(good.last)
      expect(important_vm_model.all.count).to eq(3)
      expect(important_vm_model.all.order('id desc').first).to eq(good.last)
      expect(important_vm_model.where(:id => good.last.id).count).to eq(1)
      expect(important_vm_model.where(:id => bad.last.id).count).to eq(0)
    end
  end
end
