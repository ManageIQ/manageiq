require "spec_helper"
require 'vmdb_helper'

describe Vmdb::GlobalMethods do
  before do
    class TestClass
      include Vmdb::GlobalMethods
    end
  end

  after do
    Object.send(:remove_const, :TestClass)
  end

  subject { TestClass.new }

  context "#get_timezone_offset" do
    before do
      _, @server, _ = EvmSpecHelper.create_guid_miq_server_zone
    end

    context "for a server" do
      it "with a system default" do
        stub_server_configuration(:server => {:timezone => "Eastern Time (US & Canada)"})

        Timecop.freeze(Time.utc(2013, 1, 1)) do
          subject.get_timezone_offset.should == -5.hours
        end
      end

      it "without a system default" do
        stub_server_configuration({})
        subject.get_timezone_offset.should == 0.hours
      end
    end

    context "for a user" do
      it "who doesn't exist" do
        TestClass.any_instance.stub(:session => {:userid => "missing"})

        subject.get_timezone_offset("user").should == 0.hours
      end

      it "with a timezone" do
        user = FactoryGirl.create(:user, :settings => {:display => {:timezone => "Pacific Time (US & Canada)"}})
        TestClass.any_instance.stub(:session => {:userid => user.userid})

        Timecop.freeze(Time.utc(2013, 1, 1)) do
          subject.get_timezone_offset("user").should == -8.hours
        end
      end

      context "without a timezone" do
        before do
          user = FactoryGirl.create(:user)
          TestClass.any_instance.stub(:session => {:userid => user.userid})
        end

        it "with a system default" do
          stub_server_configuration(:server => {:timezone => "Eastern Time (US & Canada)"})

          Timecop.freeze(Time.utc(2013, 1, 1)) do
            subject.get_timezone_offset("user").should == -5.hours
          end
        end

        it "without a system default" do
          stub_server_configuration({})

          subject.get_timezone_offset("user").should == ActiveSupport::TimeZone.all # TODO: This is most definitely wrong.  Should be 0.hours?
        end
      end
    end
  end

  context "#get_timezone_for_userid" do
    before do
      _, @server, _ = EvmSpecHelper.create_guid_miq_server_zone
    end

    context "for a user" do
      it "who doesn't exist" do
        subject.get_timezone_for_userid("missing").should == "UTC"
      end

      it "with a timezone" do
        user = FactoryGirl.create(:user, :settings => {:display => {:timezone => "Pacific Time (US & Canada)"}})
        subject.get_timezone_for_userid(user.userid).should == "Pacific Time (US & Canada)"
      end

      context "without a timezone" do
        it "with a system default" do
          stub_server_configuration(:server => {:timezone => "Eastern Time (US & Canada)"})

          user = FactoryGirl.create(:user)
          subject.get_timezone_for_userid(user.userid).should == "Eastern Time (US & Canada)"
        end

        it "without a system default" do
          stub_server_configuration({})

          user = FactoryGirl.create(:user)
          subject.get_timezone_for_userid(user.userid).should be_nil # TODO: Is this correct? Should it be "UTC"?
        end
      end
    end
  end

  def stub_server_configuration(config)
    VMDB::Config.any_instance.stub(:config => config)
    @server.stub(:get_config => VMDB::Config.new("vmdb"))
  end
end
