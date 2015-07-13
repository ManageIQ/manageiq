require "spec_helper"

describe Vmdb::FastGettextHelper do
  describe ".register_locales" do
    it "registers locales across all threads" do
      Thread.new { I18n.locale = 'en-US'; expect(I18n.locale).to eq(:en) }.join
    end
  end
end
