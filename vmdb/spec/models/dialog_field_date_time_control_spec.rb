require "spec_helper"

describe DialogFieldDateTimeControl do
  let!(:user) do
    user = FactoryGirl.create(:user)
    User.stub(:current_user).and_return(user)
    user
  end

  context "with UTC timezone" do
    before(:each) do
      user.stub(:get_timezone).and_return("UTC")
    end

    it "#automate_output_value with UTC timezone" do
      subject.value = "07/20/2013 16:26"
      subject.automate_output_value.should == "2013-07-20T16:26:00Z"
    end

    it "#automate_output_value in ISO format" do
      subject.value = "2013-07-20T16:26:00-05:00"
      subject.automate_output_value.should == "2013-07-20T21:26:00Z"
    end

    it "#automate_output_value in ISO format and UTC timezone" do
      subject.value = "2013-07-20T21:26:00Z"
      subject.automate_output_value.should == "2013-07-20T21:26:00Z"
    end
  end

  context "with HST timezone" do
    before(:each) do
      user.stub(:get_timezone).and_return("HST")
    end

    it "#automate_output_value" do
      subject.value = "07/20/2013 16:26"
      subject.automate_output_value.should == "2013-07-21T02:26:00Z"
    end

    it "#automate_output_value in ISO format" do
      subject.value = "2013-07-20T16:26:00-10:00"
      subject.automate_output_value.should == "2013-07-21T02:26:00Z"
    end

    it "#automate_output_value in ISO format and UTC timezone" do
      subject.value = "2013-07-20T21:26:00Z"
      subject.automate_output_value.should == "2013-07-20T21:26:00Z"
    end
  end

end
