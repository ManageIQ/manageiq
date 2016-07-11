describe ActsAsArQuery do
  let(:model) { double("model") }
  let(:query) { described_class.new(model) }

  describe "#except" do
    it "removes an expression" do
      expect(model).to receive(:find).with(:all, :limit => 5)
      query.where(:a => 1).order(:a).limit(5).except(:where, :order).to_a
    end
  end

  describe "#includes" do
    it "accepts a single table" do
      expect(model).to receive(:find).with(:all, :include => [:a])
      query.includes(:a).to_a
    end

    it "accepts multiple tables" do
      expect(model).to receive(:find).with(:all, :include => [:a, :b])
      query.includes(:a, :b).to_a
    end

    it "chains" do
      expect(model).to receive(:find).with(:all, :include => [:a, :b])
      query.includes(:a).includes(:b).to_a
    end
  end

  describe "#limit" do
    it "limits" do
      expect(model).to receive(:find).with(:all, :limit => 5)
      query.limit(5).to_a
    end
  end

  # - [.] none

  describe "#offset" do
    it "offsets" do
      expect(model).to receive(:find).with(:all, :offset => 5)
      query.offset(5).to_a
    end
  end

  describe "#order" do
    it "orders" do
      expect(model).to receive(:find).with(:all, :order => [:a])
      query.order(:a).to_a
    end

    it "accepts multiple fields" do
      expect(model).to receive(:find).with(:all, :order => [:a, :b])
      query.order(:a, :b).to_a
    end

    it "chains" do
      expect(model).to receive(:find).with(:all, :order => [:a, :b])
      query.order(:a).order(:b).to_a
    end
  end

  # - [X] references (partial) - currently ignored

  describe "#reorder" do
    it "reorders" do
      expect(model).to receive(:find).with(:all, :order => [:a])
      query.reorder(:a).to_a
    end

    it "accepts multiple fields" do
      expect(model).to receive(:find).with(:all, :order => [:a, :b])
      query.reorder(:a, :b).to_a
    end

    it "chains" do
      expect(model).to receive(:find).with(:all, :order => [:a, :b])
      query.reorder(:c, :d).reorder(:a, :b).to_a
    end

    it "order" do
      expect(model).to receive(:find).with(:all, :order => [:a, :b])
      query.order(:c).order(:d).reorder(:a, :b).to_a
    end
  end

  describe "#select" do
    it "supports single field" do
      expect(model).to receive(:find).with(:all, :select => [:a])
      query.select(:a).to_a
    end

    it "accepts multiple fields" do
      expect(model).to receive(:find).with(:all, :select => [:a, :b])
      query.select(:a, :b).to_a
    end

    it "chains fields" do
      expect(model).to receive(:find).with(:all, :select => [:c, :d, :a, :b])
      query.select(:c, :d).select(:a, :b).to_a
    end

    it "doesn't support hashes" do # TODO
      expect { query.select(:a => [:c]) }.to raise_error(ArgumentError)
    end
  end

  describe "#unscope" do
    it "removes an expression" do
      expect(model).to receive(:find).with(:all, :limit => 5)
      query.where(:a => 1).order(:a).limit(5).unscope(:where, :order).to_a
    end
  end

  describe "#where" do
    it "supports hash" do
      expect(model).to receive(:find).with(:all, :conditions => {:a => 5})
      query.where(:a => 5).to_a
    end

    it "accepts multiple fields" do
      expect(model).to receive(:find).with(:all, :conditions => {:a => 5, :b => 6})
      query.where(:a => 5, :b => 6).to_a
    end

    it "chains fields" do
      expect(model).to receive(:find).with(:all, :conditions => {:a => 5, :b => 6})
      query.where(:a => 5).where(:b => 6).to_a
    end

    it "merges hashes" do
      expect(model).to receive(:find).with(:all, :conditions => {:a => [5, 55], :b => [6, 66]})
      query.where(:a => 5, :b => 6).where(:a => 55, :b => 66).to_a
    end

    it "supports string queries" do
      expect(model).to receive(:find).with(:all, :conditions => ["x = 5"])
      query.where("x = 5").to_a
    end

    it "supports multiple arguments" do
      expect(model).to receive(:find).with(:all, :conditions => ["x = ?", 5])
      query.where("x = ?", 5).to_a
    end

    it "supports array queries" do
      expect(model).to receive(:find).with(:all, :conditions => ["x = ?", 5])
      query.where(["x = ?", 5]).to_a
    end

    it "does not merge hashes and strings" do
      expect { query.where("b = 5").where(:a => :c) }.to raise_error(ArgumentError)
    end

    it "does not merge hashes and strings" do
      expect { query.where(:a => :c).where("b = 5") }.to raise_error(ArgumentError)
    end
  end

  describe "#all" do
    it "is a no-op" do
      expect(query.all).to equal(query)
    end
  end

  describe "#count" do
    it "accepts a single table" do
      expect(model).to receive(:find).with(:all, :include => [:a]).and_return([1, 2, 3, 4, 5])
      expect(query.includes(:a).count).to eq(5)
    end
  end
  # executing

  # - [X] count
  # - [ ] find
  # - [X] first
  # - [X] last
  # - [X] size
  # - [X] take

  describe "#instances_are_derived?" do
    it "is derived" do
      expect(query).to be_instances_are_derived
    end
  end
end
