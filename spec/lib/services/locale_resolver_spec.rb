RSpec.describe LocaleResolver do
  context "when the user's locale is set" do
    before { stub_current_user_with_locale("en-US") }

    it "returns the user's locale" do
      expect(described_class.resolve).to eq("en-US")
    end
  end

  context "when the user's locale is 'default'" do
    before { stub_current_user_with_locale("default") }

    context "and the server's locale is set" do
      before { stub_server_settings_with_locale("en-US") }

      it "returns the server's locale" do
        expect(described_class.resolve).to eq("en-US")
      end
    end

    context "and the server's locale is 'default'" do
      before { stub_server_settings_with_locale("default") }

      it "returns the locale from the headers" do
        expect(described_class.resolve("Accept-Language" => "en-US")).to eq("en-US")
      end
    end

    context "and the server's locale is not set" do
      before { stub_server_settings_with_locale(nil) }

      it "returns the locale from the headers" do
        expect(described_class.resolve("Accept-Language" => "en-US")).to eq("en-US")
      end
    end
  end

  context "when the user's locale is not set" do
    before { stub_current_user_with_locale(nil) }

    context "and the server's locale is set" do
      before { stub_server_settings_with_locale("en-US") }

      it "returns the server's locale" do
        expect(described_class.resolve).to eq("en-US")
      end
    end

    context "and the server's locale is 'default'" do
      before { stub_server_settings_with_locale("default") }

      it "returns the locale from the headers" do
        expect(described_class.resolve("Accept-Language" => "en-US")).to eq("en-US")
      end
    end

    context "and the server's locale is not set" do
      before { stub_server_settings_with_locale(nil) }

      it "returns the locale from the headers" do
        expect(described_class.resolve("Accept-Language" => "en-US")).to eq("en-US")
      end
    end
  end

  def stub_current_user_with_locale(locale)
    user = instance_double(User, :settings => {:display => {:locale => locale}})
    allow(User).to receive(:current_user).and_return(user)
  end

  def stub_server_settings_with_locale(locale)
    allow(Settings.server).to receive(:locale).and_return(locale)
  end
end
