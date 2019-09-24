RSpec.describe LocaleResolver do
  context "when the user's locale is set" do
    it "returns the user's locale" do
      user = instance_double(User, :settings => {:display => {:locale => "en-US"}})
      expect(described_class.resolve(user)).to eq("en-US")
    end
  end

  context "when the user's locale is 'default'" do
    context "and the server's locale is set" do
      before { stub_settings(:server => {:locale => "en-US"}) }

      it "returns the server's locale" do
        user = instance_double(User, :settings => {:display => {:locale => "default"}})
        expect(described_class.resolve(user)).to eq("en-US")
      end
    end

    context "and the server's locale is 'default'" do
      before { stub_settings(:server => {:locale => "default"}) }

      it "returns the locale from the headers" do
        user = instance_double(User, :settings => {:display => {:locale => "default"}})
        expect(described_class.resolve(user, "Accept-Language" => "en-US")).to eq("en-US")
      end
    end

    context "and the server's locale is not set" do
      before { stub_settings(:server => {:locale => nil}) }

      it "returns the locale from the headers" do
        user = instance_double(User, :settings => {:display => {:locale => "default"}})
        expect(described_class.resolve(user, "Accept-Language" => "en-US")).to eq("en-US")
      end
    end
  end

  context "when the user's locale is not set" do
    context "and the server's locale is set" do
      before { stub_settings(:server => {:locale => "en-US"}) }

      it "returns the server's locale" do
        user = instance_double(User, :settings => {:display => {:locale => nil}})
        expect(described_class.resolve(user)).to eq("en-US")
      end
    end

    context "and the server's locale is 'default'" do
      before { stub_settings(:server => {:locale => "default"}) }

      it "returns the locale from the headers" do
        user = instance_double(User, :settings => {:display => {:locale => nil}})
        expect(described_class.resolve(user, "Accept-Language" => "en-US")).to eq("en-US")
      end
    end

    context "and the server's locale is not set" do
      before { stub_settings(:server => {:locale => nil}) }

      it "returns the locale from the headers" do
        user = instance_double(User, :settings => {:display => {:locale => nil}})
        expect(described_class.resolve(user, "Accept-Language" => "en-US")).to eq("en-US")
      end
    end
  end
end
