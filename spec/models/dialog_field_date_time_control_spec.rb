RSpec.describe DialogFieldDateTimeControl do
  context "legacy tests" do
    let!(:user) do
      User.current_user = FactoryBot.create(:user)
    end

    context "with UTC timezone" do
      before do
        allow(user).to receive(:get_timezone).and_return("UTC")
      end

      it "#automate_output_value with UTC timezone" do
        subject.value = "07/20/2013 16:26"
        expect(subject.automate_output_value).to eq("2013-07-20T16:26:00Z")
      end

      it "#automate_output_value in ISO format" do
        subject.value = "2013-07-20T16:26:00-05:00"
        expect(subject.automate_output_value).to eq("2013-07-20T21:26:00Z")
      end

      it "#automate_output_value in ISO format and UTC timezone" do
        subject.value = "2013-07-20T21:26:00Z"
        expect(subject.automate_output_value).to eq("2013-07-20T21:26:00Z")
      end
    end

    context "with HST timezone" do
      before do
        allow(user).to receive(:get_timezone).and_return("HST")
      end

      it "#automate_output_value" do
        subject.value = "07/20/2013 16:26"
        expect(subject.automate_output_value).to eq("2013-07-21T02:26:00Z")
      end

      it "#automate_output_value in ISO format" do
        subject.value = "2013-07-20T16:26:00-10:00"
        expect(subject.automate_output_value).to eq("2013-07-21T02:26:00Z")
      end

      it "#automate_output_value in ISO format and UTC timezone" do
        subject.value = "2013-07-20T21:26:00Z"
        expect(subject.automate_output_value).to eq("2013-07-20T21:26:00Z")
      end
    end
  end

  describe "#automate_output_value" do
    let(:dialog_field) { described_class.new(:value => value) }
    let(:server) { double("MiqServer", :server_timezone => "UTC") }

    before do
      allow(MiqServer).to receive(:my_server).and_return(server)
    end

    context "when the dialog_field is blank" do
      let(:value) { "" }

      it "returns nil" do
        expect(dialog_field.automate_output_value).to be_nil
      end
    end

    context "when the dialog_field has a value" do
      context "when the value is a date formatted in ISO" do
        let(:value) { "2013-08-07T12:34:00+00:00" }

        it "returns the date and time in ISO format" do
          expect(dialog_field.automate_output_value).to eq("2013-08-07T12:34:00Z")
        end
      end

      context "when the value is a date formatted in %m/%d/%Y %H:%M" do
        let(:value) { "08/07/2013 12:34" }

        it "returns the date in ISO format" do
          expect(dialog_field.automate_output_value).to eq("2013-08-07T12:34:00Z")
        end
      end
    end
  end

  describe "#value" do
    let(:dialog_field) { described_class.new(:dynamic => dynamic, :value => value) }
    let(:server) { double("MiqServer", :server_timezone => "UTC") }

    before do
      allow(MiqServer).to receive(:my_server).and_return(server)
    end

    context "when the value is not blank" do
      let(:value) { "04/07/2015 00:00" }

      context "when the field is dynamic" do
        let(:dynamic) { true }

        it "returns the current value" do
          expect(dialog_field.value).to eq("04/07/2015 00:00")
        end
      end

      context "when the field is not dynamic" do
        let(:dynamic) { false }

        it "returns the current value" do
          expect(dialog_field.value).to eq("04/07/2015 00:00")
        end
      end
    end

    context "when the value is blank" do
      let(:value) { "" }

      context "when the field is dynamic" do
        let(:dynamic) { true }

        it "returns tomorrow's date" do
          Timecop.freeze(Time.utc(2015, 1, 2, 4, 30)) do
            expect(dialog_field.value).to eq("01/03/2015 04:30")
          end
        end
      end

      context "when the field is not dynamic" do
        let(:dynamic) { false }

        it "returns tomorrow's date" do
          Timecop.freeze(Time.utc(2015, 1, 2, 4, 30)) do
            expect(dialog_field.value).to eq("01/03/2015 04:30")
          end
        end
      end
    end
  end

  describe "#refresh_json_value" do
    let(:dialog_field) { described_class.new(:read_only => true) }
    let(:server) { double("MiqServer", :server_timezone => "UTC") }

    before do
      allow(MiqServer).to receive(:my_server).and_return(server)
      allow(DynamicDialogFieldValueProcessor).to receive(:values_from_automate)
        .with(dialog_field).and_return("2015-02-03T18:50:00Z")
    end

    it "returns the default value in a hash" do
      expect(dialog_field.refresh_json_value).to eq(
        :date      => "02/03/2015",
        :hour      => "18",
        :min       => "50",
        :read_only => true,
        :visible   => true
      )
    end

    it "assigns the processed value to value" do
      dialog_field.refresh_json_value
      expect(dialog_field.value).to eq("02/03/2015 18:50")
    end
  end
end
