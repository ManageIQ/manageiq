require "spec_helper"
include JsHelper

describe "dashboard/login.html.haml" do

  context "login_div contains browser and TZ hidden fields" do
    before(:each) do
      EvmSpecHelper.create_guid_miq_server_zone
      view.stub(:get_vmdb_config).and_return(:server => {}, :session => {}, :authentication => {})
    end

    it "when authentication is 'database'" do
      User.stub(:mode).and_return("database")
      render
      response.should have_selector("div#login_div:has(input#browser_name)")
      response.should have_selector("div#login_div:has(input#browser_version)")
      response.should have_selector("div#login_div:has(input#browser_os)")
      response.should have_selector("div#login_div:has(input#user_TZO)")
    end

    it "when authentication is not 'database'" do
      User.stub(:mode).and_return("ldap")
      render
      response.should have_selector("div#login_div:has(input#browser_name)")
      response.should have_selector("div#login_div:has(input#browser_version)")
      response.should have_selector("div#login_div:has(input#browser_os)")
      response.should have_selector("div#login_div:has(input#user_TZO)")
    end
  end

  context "on screen region/zone/appliance info" do
    before(:each) do
      EvmSpecHelper.create_guid_miq_server_zone
      MiqRegion.seed
      @labels = ['Region:', 'Zone:', 'Appliance:']
    end

    it "show" do
      view.stub(:get_vmdb_config).and_return(:server => {},
        :session => {:show_login_info => true}, :authentication => {})
      render
      @labels.each do |label|
        response.should have_selector('p', :text => label)
      end
    end

    it "hide" do
      view.stub(:get_vmdb_config).and_return(:server => {},
        :session => {:show_login_info => false}, :authentication => {})
      render
      @labels.each do |label|
        response.should_not have_selector('p', :text => label)
      end
    end
  end

end
