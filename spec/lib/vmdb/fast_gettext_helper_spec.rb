RSpec.describe Vmdb::FastGettextHelper do
  describe ".register_locales" do
    it "registers locales across all threads" do
      Thread.new do
        I18n.locale = 'en-US'
        expect(I18n.locale).to eq(:en)
      end.join
    end
  end
end
