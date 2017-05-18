RSpec.describe Api::RequestParser do
  describe ".parse_user" do
    it "returns nil if no username is provided" do
      expect(described_class.parse_user({})).to be_nil
    end

    it "returns the user identified with the username" do
      username = "foo"
      user = instance_double(User)
      allow(User).to receive(:lookup_by_identity).with(username).and_return(user)

      actual = described_class.parse_user("requester" => {"user_name" => username})

      expect(actual).to eq(user)
    end

    it "raises if the user cannot be found" do
      allow(User).to receive(:lookup_by_identity).and_return(nil)

      expect do
        described_class.parse_user("requester" => {"user_name" => "foo"})
      end.to raise_error(Api::BadRequestError, /unknown requester/i)
    end
  end

  describe ".parse_options" do
    it "raises if there are no options" do
      expect { described_class.parse_options({}) }.to raise_error(Api::BadRequestError, /missing options/)
    end

    it "symbolizes keys" do
      actual = described_class.parse_options("options" => {"foo" => "bar"})
      expected = {:foo => "bar"}
      expect(actual).to eq(expected)
    end
  end

  describe ".parse_auto_approve" do
    it "returns true if true" do
      expect(described_class.parse_auto_approve("auto_approve" => true)).to be true
    end

    it "returns true if 'true'" do
      expect(described_class.parse_auto_approve("auto_approve" => "true")).to be true
    end

    it "returns false if false" do
      expect(described_class.parse_auto_approve("auto_approve" => false)).to be false
    end

    it "returns false if 'false'" do
      expect(described_class.parse_auto_approve("auto_approve" => "false")).to be false
    end

    it "returns false if nil" do
      expect(described_class.parse_auto_approve({})).to be false
    end

    it "raises if anything else" do
      expect do
        described_class.parse_auto_approve("auto_approve" => "foo")
      end.to raise_error(Api::BadRequestError, /invalid requester auto_approve value/i)
    end
  end
end
