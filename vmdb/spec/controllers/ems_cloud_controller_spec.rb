require "spec_helper"

describe EmsCloudController do
  context "create" do
    before(:each) do
      set_user_privileges
      @zone = FactoryGirl.create :zone
    end

    render_views

    it "creates an ems successfully" do
      expect {
        post :create, {
          :button           => 'add',  # legacy
          :name             => "aaron's ems",
          :server_emstype   => "openstack",
          :hostname         => "wow.local",
          :ipaddress        => "127.0.0.1",
          :server_zone      => @zone.name,
          :default_userid   => 'aaron',
          :default_password => 'secret',
        }
      }.to change { EmsOpenstack.count }
    end

    it "doesn't create an ems" do
      expect {
        post :create, {
          :button           => 'add',  # legacy
          :name             => "aaron's ems",
          :server_emstype   => "openstack",
        }
      }.to_not change { EmsOpenstack.count }
    end

    it "displays correct attribute name in error message when adding cloud EMS" do
      post :create, {
        :button           => 'add',  # legacy
        :name             => "EMS 1",
        :server_emstype   => "ec2",
        :hostname         => "wow.local",
        :ipaddress        => "127.0.0.1",
        :server_zone      => @zone.name,
        :default_userid   => 'aaron',
        :default_password => 'secret',
      }
      flash_messages = assigns(:flash_array)
      flash_messages.first[:message].should include("Region is not included in the list")
      flash_messages.first[:level].should == :error
    end

    it "displays correct attribute name in error message when adding infra EMS" do
      post :create, {
        :button           => 'add',  # legacy
        :name             => "EMS 2",
        :server_emstype   => "rhevm",
        :ipaddress        => "127.0.0.1",
        :server_zone      => @zone.name,
        :default_userid   => 'aaron',
        :default_password => 'secret',
      }
      post :create, :button => "add"
      flash_messages = assigns(:flash_array)
      flash_messages.first[:message].should include("Host Name can't be blank")
      flash_messages.first[:level].should == :error
    end
  end
end
