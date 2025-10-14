RSpec.describe ActsAsArModel do
  # id is a default column included regardless if it's in the set_columns_hash
  let(:col_names_strs) { %w[str id int flt dt] }

  let(:base_class) do
    Class.new(ActsAsArModel) do
      set_columns_hash(
        :str              => :string,
        :int              => :integer,
        :flt              => :float,
        :dt               => :datetime
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

  describe ".all" do
    it "comes from QueryRelation" do
      expect(base_class).to receive(:search).with(:all, {}).and_return([])
      expect(base_class.all.to_a).to eq([])
    end

    it "supports where from QueryRelation (as an example)" do
      expect(base_class).to receive(:search).with(:all, {:where => {:id => 5}}).and_return([])
      expect(base_class.all.where(:id => 5).to_a).to eq([])
    end
  end

  describe ".first" do
    it "comes from QueryRelation" do
      expect(base_class).to receive(:search).with(:first, {}).and_return(nil)
      expect(base_class.first).to eq(nil)
    end
  end

  describe ".last" do
    it "comes from QueryRelation" do
      expect(base_class).to receive(:search).with(:last, {}).and_return(nil)
      expect(base_class.last).to eq(nil)
    end
  end

  describe ".count" do
    it "comes from QueryRelation" do
      expect(base_class).to receive(:search).with(:all, {}).and_return([])
      expect(base_class.count).to eq(0)
    end
  end

  describe ".find (deprecated)" do
    around do |example|
      Vmdb::Deprecation.silence do
        example.run
      end
    end

    describe "find(:all)" do
      it "chains through QueryRelation" do
        expect(base_class).to receive(:search).with(:all, {}).and_return([])
        expect(base_class.find(:all).to_a).to eq([])
      end

      it "supports :conditions legacy option (as an example)" do
        expect(base_class).to receive(:search).with(:all, {:where => {:id => 5}}).and_return([])
        expect(base_class.find(:all, :conditions => {:id => 5}).to_a).to eq([])
      end
    end

    describe "find(:first)" do
      it "chains through QueryRelation" do
        expect(base_class).to receive(:search).with(:first, {}).and_return(nil)
        expect(base_class.find(:first)).to eq(nil)
      end
    end

    describe ".find(:last)" do
      it "chains through QueryRelation" do
        expect(base_class).to receive(:search).with(:last, {}).and_return(nil)
        expect(base_class.find(:last)).to eq(nil)
      end
    end
  end

  describe ".find" do
    it "finds a record by id" do
      expected = Object.new
      expect(base_class).to receive(:search).with(:first, {:where => {:id => 5}}).and_return(expected)
      expect(base_class.find(5)).to eq(expected)
    end

    it "raises when not found" do
      expect(base_class).to receive(:search).with(:first, {:where => {:id => 5}}).and_return(nil)
      expect { base_class.find(5) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe ".lookup_by_id" do
    it "finds a record by id" do
      expected = Object.new
      expect(base_class).to receive(:search).with(:first, {:where => {:id => 5}}).and_return(expected)
      expect(base_class.lookup_by_id(5)).to eq(expected)
    end

    it "returns nil when not found" do
      expect(base_class).to receive(:search).with(:first, {:where => {:id => 5}}).and_return(nil)
      expect(base_class.lookup_by_id(5)).to be_nil
    end
  end

  describe ".find_by_id (deprecated)" do
    around do |example|
      Vmdb::Deprecation.silence do
        example.run
      end
    end

    it "finds a record by id" do
      expected = Object.new
      expect(base_class).to receive(:search).with(:first, {:where => {:id => 5}}).and_return(expected)
      expect(base_class.find_by_id(5)).to eq(expected)
    end

    it "returns nil when not found" do
      expect(base_class).to receive(:search).with(:first, {:where => {:id => 5}}).and_return(nil)
      expect(base_class.find_by_id(5)).to be_nil
    end
  end

  describe ".find_all_by_id (deprecated)" do
    around do |example|
      Vmdb::Deprecation.silence do
        example.run
      end
    end

    it "finds record by ids" do
      expected = [Object.new, Object.new]
      expect(base_class).to receive(:search).with(:all, {:where => {:id => [5, 6]}}).and_return(expected)
      expect(base_class.find_all_by_id(5, 6)).to eq(expected)
    end

    it "returns empty Array when none found" do
      expect(base_class).to receive(:search).with(:all, {:where => {:id => [5, 6]}}).and_return([])
      expect(base_class.find_all_by_id(5, 6)).to eq([])
    end
  end
end
