require "spec_helper"

describe DialogFieldDateControl do

  it "#automate_output_value" do
    subject.value = "08/07/2013"
    subject.automate_output_value.should == "2013-08-07"
  end

  it "#automate_output_value with ISO value" do
    subject.value = "2013-08-07"
    subject.automate_output_value.should == "2013-08-07"
  end

  it "#default_value" do
    subject.class.stub(:server_timezone).and_return("EST")
    Time.stub(:now).and_return(Time.parse("2013-08-08T18:01:32Z"))
    subject.default_value.should == "08/09/2013"
  end

  context "#show_past_dates" do
    it "default" do
      subject.show_past_dates.should == false
    end

    it "when true" do
      subject.show_past_dates = true
      subject.options[:show_past_dates].should be_true
      subject.show_past_dates.should be_true
    end

    it "when false" do
      subject.show_past_dates = false
      subject.options[:show_past_dates].should be_false
      subject.show_past_dates.should be_false
    end
  end

end
