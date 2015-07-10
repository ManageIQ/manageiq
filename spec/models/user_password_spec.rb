require "spec_helper"
require 'bcrypt'

describe "User Password" do
  context "With admin user" do
    before(:each) do
      MiqRegion.seed
      guid, server, @zone = EvmSpecHelper.create_guid_miq_server_zone

      @old = 'smartvm'
      @admin = FactoryGirl.create(:user, :userid => 'admin',
                                  :password_digest => BCrypt::Password.create(@old))
    end

    it "should have set password" do
      @admin.authenticate_bcrypt(@old).should == @admin
    end

    context "call change_password" do
      before(:each) do
        @new = 'Zug-drep5s'
        @admin.change_password(@old, @new)
      end

      it "should change password" do
        @admin.authenticate_bcrypt(@new).should == @admin
      end

    end

    context "call password=" do
      before(:each) do
        @new = 'Zug-drep5s'
        @admin.password = @new
        @admin.save!
      end

      it "should change password" do
        @admin.authenticate_bcrypt(@new).should == @admin
      end
    end
  end
end
