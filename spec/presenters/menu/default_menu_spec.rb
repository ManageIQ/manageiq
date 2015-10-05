require "spec_helper"
require_relative "menu_spec_helper"

include MenuSpecHelper

describe Menu::DefaultMenu do
  context 'default_menu' do
    it "does not call gettext translations" do
      expect(Menu::DefaultMenu).not_to receive(:ui_lookup).with(any_args)
      expect(Menu::DefaultMenu).not_to receive(:_)
      expect(Menu::DefaultMenu).not_to receive(:n_)
      Menu::DefaultMenu.default_menu
    end

    it "calls gettext marker" do
      expect(Menu::DefaultMenu).to receive(:N_).at_least(:once).and_call_original
      Menu::DefaultMenu.default_menu
    end
  end
end
