require "spec_helper"

describe DialogFieldDateTimeControl do
  context "legacy tests" do
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

  describe "#value" do
    let(:dialog_field) { described_class.new(:dynamic => dynamic) }

    context "when the field is dynamic" do
      let(:dynamic) { true }

      before do
        DynamicDialogFieldValueProcessor.stub(:values_from_automate).with(dialog_field).and_return("2015-01-02")
        dialog_field.value = nil
      end

      it "returns the values from the value processor" do
        expect(dialog_field.value).to eq("01/02/2015 00:00")
      end
    end

    context "when the field is not dynamic" do
      let(:dynamic) { false }

      before do
        described_class.stub(:server_timezone).and_return("UTC")
      end

      it "returns tomorrow's date" do
        Timecop.freeze(Time.utc(2015, 1, 2, 4, 30)) do
          expect(dialog_field.value).to eq("01/03/2015 04:30")
        end
      end
    end
  end

  describe "#refresh_json_value" do
    let(:dialog_field) { described_class.new }

    before do
      described_class.stub(:server_timezone).and_return("Hawaii")
    end

    it "returns the default value in a hash" do
      Timecop.freeze(Time.utc(2015, 2, 3, 4, 50)) do
        expect(dialog_field.refresh_json_value).to eq(
          :date => "02/03/2015",
          :hour => "18",
          :min  => "50"
        )
      end
    end
  end
end
