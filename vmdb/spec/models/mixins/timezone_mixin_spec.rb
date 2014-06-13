require "spec_helper"

describe TimezoneMixin do
  before do
    class TestClass
      include TimezoneMixin
    end
  end

  before(:each) do
      guid = MiqUUID.new_guid
      MiqServer.stub(:my_guid).and_return(guid)

      zone        = FactoryGirl.create(:zone)
      miq_server  = FactoryGirl.create(:miq_server, :zone => zone, :guid => guid)
      MiqServer.my_server(true)
  end

  after do
    Object.send(:remove_const, "TestClass")
  end

  context ".server_timezone" do
    it "default" do
      Hash.any_instance.stub(:fetch_path).and_return(nil)
      TestClass.server_timezone.should == "UTC"
    end

    it "server default" do
      Hash.any_instance.stub(:fetch_path).and_return("Eastern Time (US & Canada)")
      TestClass.server_timezone.should == "Eastern Time (US & Canada)"
    end
  end

  context "with a class instance" do
    let(:test_inst) { TestClass.new }

    it "#with_a_timezone in Hawaii" do
      test_inst.with_a_timezone("Hawaii") { Time.zone }.to_s.should == "(GMT-10:00) Hawaii"
    end

    it "#with_a_timezone in GMT" do
      test_inst.with_a_timezone("UTC") { Time.zone }.to_s.should == "(GMT+00:00) UTC"
    end

    it "#with_current_user_timezone" do
      test_inst.with_current_user_timezone { Time.zone }.to_s.should == "(GMT+00:00) UTC"
    end

    context "with a user" do
      let!(:user) do
        user = FactoryGirl.create(:user)
        User.stub(:current_user).and_return(user)
        user
      end

      it "#with_current_user_timezone in GMT" do
        user.stub(:get_timezone).and_return("UTC")
        test_inst.with_current_user_timezone { Time.zone }.to_s.should == "(GMT+00:00) UTC"
      end

      it "#with_current_user_timezone in Hawaii" do
        user.stub(:get_timezone).and_return("Hawaii")
        test_inst.with_current_user_timezone { Time.zone }.to_s.should == "(GMT-10:00) Hawaii"
      end
    end
  end
end
