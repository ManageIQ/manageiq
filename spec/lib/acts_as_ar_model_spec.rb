describe ActsAsArModel do
  before { base_class }

  # id is a default column included regardless if it's in the set_columns_hash
  let(:col_names_syms) { [:str, :id, :int, :flt, :dt] }
  let(:col_names_strs) { %w(str id int flt dt) }

  let(:base_class) do
    Class.new(ActsAsArModel) do
      set_columns_hash(
        :str              => :string,
        :int              => :integer,
        :flt              => :float,
        :dt               => :datetime,
      )
    end
  end

  describe "subclass, base_class," do
    it(".base_class") { expect(base_class.base_class).to eq(base_class) }
    it(".base_model") { expect(base_class.base_model).to eq(base_class) }

    it { expect(base_class.attribute_names).to match_array(col_names_strs) }

    describe "instance" do
      it { expect(base_class.new).to respond_to(:attributes) }
      it { expect(base_class.new).to respond_to(:str) }

      it "should allow attribute initialization" do
        t = base_class.new(:str => "test_value")
        expect(t.str).to eq("test_value")
      end

      it "should allow attribute access" do
        t = base_class.new
        expect(t.str).to be_nil

        t.str = "test_value"
        expect(t.str).to eq("test_value")
      end
    end

    describe "subclass, TestSubClass1," do
      let(:sub_class) { Class.new(base_class) }

      it(".base_class") { expect(sub_class.base_class).to eq(base_class) }
      it(".base_model") { expect(sub_class.base_model).to eq(base_class) }
    end
  end

  describe "subclass, TestClass2," do
    let(:sub_class) { Class.new(ActsAsArModel) }

    it(".base_class") { expect(sub_class.base_class).to eq(sub_class) }
    it(".base_model") { expect(sub_class.base_model).to eq(sub_class) }

    it { expect(sub_class.attribute_names).to be_empty }
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
