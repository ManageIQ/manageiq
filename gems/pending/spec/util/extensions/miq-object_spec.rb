require 'util/extensions/miq-object'

describe Object do
  context "#deep_send" do
    it "with string" do
      expect(10.deep_send("to_s")).to eq("10")
      expect(10.deep_send("to_s.length")).to eq(2)
      expect(10.deep_send("to_s.length.to_s")).to eq("2")
      expect([].deep_send("first.length")).to be_nil
    end

    it "with array of strings" do
      expect(10.deep_send(["to_s"])).to eq("10")
      expect(10.deep_send(["to_s", "length"])).to eq(2)
      expect(10.deep_send(["to_s", "length", "to_s"])).to eq("2")
      expect(10.deep_send(["to_s", "length.to_s"])).to eq("2")
      expect(10.deep_send(["to_s.length", "to_s.length"])).to eq(1)
      expect([].deep_send(["first", "length"])).to be_nil
    end

    it "with direct strings" do
      expect(10.deep_send("to_s")).to eq("10")
      expect(10.deep_send("to_s", "length")).to eq(2)
      expect(10.deep_send("to_s", "length", "to_s")).to eq("2")
      expect(10.deep_send("to_s", "length.to_s")).to eq("2")
      expect(10.deep_send("to_s.length", "to_s.length")).to eq(1)
      expect([].deep_send("first", "length")).to be_nil
    end

    it "with array of symbols" do
      expect(10.deep_send([:to_s])).to eq("10")
      expect(10.deep_send([:to_s, :length])).to eq(2)
      expect(10.deep_send([:to_s, :length, "to_s"])).to eq("2")
      expect([].deep_send([:first, :length])).to be_nil
    end

    it "with direct symbols" do
      expect(10.deep_send(:to_s)).to eq("10")
      expect(10.deep_send(:to_s, :length)).to eq(2)
      expect(10.deep_send(:to_s, :length, "to_s")).to eq("2")
      expect([].deep_send(:first, :length)).to be_nil
    end

    it "with invalid" do
      expect { 10.deep_send }.to raise_error(ArgumentError)
      expect { 10.deep_send(nil) }.to raise_error(ArgumentError)
      expect { 10.deep_send("") }.to raise_error(ArgumentError)
    end

    it "does not damage args" do
      args = ["to_s", "length", "to_s"]
      10.deep_send(args)
      expect(args).to eq(["to_s", "length", "to_s"])

      args = ["to_s", "length", "to_s"]
      10.deep_send(*args)
      expect(args).to eq(["to_s", "length", "to_s"])
    end
  end
end
