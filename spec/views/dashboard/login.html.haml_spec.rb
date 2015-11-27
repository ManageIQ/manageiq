require "spec_helper"
include JsHelper

describe "dashboard/login.html.haml" do
  context "login_div contains browser and TZ hidden fields" do
    before(:each) do
      EvmSpecHelper.create_guid_miq_server_zone
      stub_server_configuration(:server => {}, :session => {}, :authentication => {})
    end

    it "when authentication is 'database'" do
      view.stub(:current_tenant).and_return(Tenant.seed)
      User.stub(:mode).and_return("database")
      render
      response.should have_selector("div#login_div:has(input#browser_name)")
      response.should have_selector("div#login_div:has(input#browser_version)")
      response.should have_selector("div#login_div:has(input#browser_os)")
      response.should have_selector("div#login_div:has(input#user_TZO)")
    end

    it "when authentication is not 'database'" do
      view.stub(:current_tenant).and_return(Tenant.seed)
      User.stub(:mode).and_return("ldap")
      render
      response.should have_selector("div#login_div:has(input#browser_name)")
      response.should have_selector("div#login_div:has(input#browser_version)")
      response.should have_selector("div#login_div:has(input#browser_os)")
      response.should have_selector("div#login_div:has(input#user_TZO)")
    end
  end

  context "on screen region/zone/appliance info" do
    let(:labels) { %w(Region: Zone: Appliance:) }
    before(:each) do
      EvmSpecHelper.create_guid_miq_server_zone
      MiqRegion.seed
    end

    it "show" do
      view.stub(:current_tenant).and_return(Tenant.seed)
      view.stub(:get_vmdb_config).and_return(:server => {},
        :session => {:show_login_info => true}, :authentication => {})
      render
      labels.each do |label|
        response.should have_selector('p', :text => label)
      end
    end

    it "hide" do
      view.stub(:current_tenant).and_return(Tenant.seed)
      view.stub(:get_vmdb_config).and_return(:server => {},
        :session => {:show_login_info => false}, :authentication => {})
      render
      labels.each do |label|
        response.should_not have_selector('p', :text => label)
      end
    end
  end
end
