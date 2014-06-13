require "spec_helper"
require 'bcrypt'

describe "User Password" do
  def read_miq_pass
    filename = File.exists?("config/miq_pass") ? "config/miq_pass" : "config/miq_pass_default"
    File.open(File.join(Rails.root, filename), 'r') {|f| f.read.chomp }
  end

  def save_old_miq_pass
    @has_miq_pass = File.exists?("config/miq_pass")
    @old_miq_pass = read_miq_pass
  end

  def restore_old_miq_pass
    if @has_miq_pass
      File.open(File.join(Rails.root, "config/miq_pass"), 'w') {|f| f.write(@old_miq_pass) }
    else
      File.delete("config/miq_pass") if File.exists?("config/miq_pass")
    end
  end

  context "With admin user" do
    before(:each) do
      MiqRegion.seed
      guid, server, @zone = EvmSpecHelper.create_guid_miq_server_zone


      save_old_miq_pass
      @old = 'smartvm'
      @admin = FactoryGirl.create(:user, :userid => 'admin',
                                  :password_digest => BCrypt::Password.create(@old))
    end

    after(:each) do
      restore_old_miq_pass
    end

    it "should have set password" do
      @admin.authenticate_bcrypt(@old).should == @admin
    end

    it "should have miq_pass match current password" do
      BCrypt::Password.new(self.read_miq_pass).should == @old
    end

    context "call change_password" do
      before(:each) do
        @new = 'Zug-drep5s'
        @admin.change_password(@old, @new)
      end

      it "should change password" do
        @admin.authenticate_bcrypt(@new).should == @admin
      end

      it "should write miq_pass file with new password" do
        BCrypt::Password.new(self.read_miq_pass).should == @new
        BCrypt::Password.new(self.read_miq_pass).should_not == @old
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

      it "should write miq_pass file with new password" do
        BCrypt::Password.new(self.read_miq_pass).should == @new
        BCrypt::Password.new(self.read_miq_pass).should_not == @old
      end
    end

    context "#sync_admin_password" do
      before(:each) do
        @new = 'Zug-drep5s'
        @admin.password = @new
      end

      it "normal case" do
        @admin.sync_admin_password
        BCrypt::Password.new(self.read_miq_pass).should == @new
      end

      it "writes new password to the provided IO object" do
        str = StringIO.new
        @admin.sync_admin_password(str)
        str.rewind
        BCrypt::Password.new(str.read.chomp).should == @new
      end
    end

    context "#on_changed_admin_password" do
      before(:each) do
        @server2 = FactoryGirl.create(:miq_server, :guid => MiqUUID.new_guid, :zone => @zone)
        @new = 'Zug-drep5s'
      end

      it "calls sync_admin_password" do
        @admin.should_receive(:sync_admin_password).once
        @admin.password = @new
        @admin.save!
      end

      it "queues sync_admin_password for other servers in the region" do
        @admin.password = @new
        @admin.save!
        MiqQueue.count.should == 1
        message = MiqQueue.first
        message.class_name.should  == "User"
        message.method_name.should == "sync_admin_password"
        message.server_guid.should == @server2.guid
        message.priority.should    == MiqQueue::HIGH_PRIORITY
      end

      it "doesn't call sync_admin_password when password unchanged" do
        @admin.should_receive(:sync_admin_password).never
        @admin.save!
      end
    end
  end
end
