require "spec_helper"

describe DialogFieldDateControl do
  describe "#default_value" do
    let(:dialog_field) { described_class.new(:dynamic => dynamic) }

    context "when the field is dynamic" do
      let(:dynamic) { true }

      before do
        DynamicDialogFieldValueProcessor.stub(:values_from_automate).with(dialog_field).and_return("processor")
      end

      it "returns the values from the value processor" do
        expect(dialog_field.default_value).to eq("processor")
      end
    end

    context "when the field is not dynamic" do
      let(:dynamic) { false }

      before do
        described_class.stub(:server_timezone).and_return("UTC")
      end

      it "returns tomorrow's date" do
        Timecop.freeze(Time.new(2015, 1, 2)) do
          expect(dialog_field.default_value).to eq("01/03/2015")
        end
      end
    end
  end

  describe "#normalize_automate_values" do
    let(:dialog_field) { described_class.new(:dynamic => true) }
    let(:automate_hash) do
      {
        "default_value"   => default_value,
        "show_past_dates" => true
      }
    end

    shared_examples_for "DialogFieldDateControl#normalize_automate_values" do
      before do
        dialog_field.normalize_automate_values(automate_hash)
      end

      it "sets the show_past_dates" do
        expect(dialog_field.show_past_dates).to be_true
      end
    end

    context "when the automate hash has a default value" do
      let(:default_value) { "01/02/2015" }

      it_behaves_like "DialogFieldDateControl#normalize_automate_values"

      it "sets the default value" do
        dialog_field.normalize_automate_values(automate_hash)
        expect(dialog_field.read_attribute(:default_value)).to eq("01/02/2015")
      end

      it "returns the default value" do
        expect(dialog_field.normalize_automate_values(automate_hash)).to eq("01/02/2015")
      end
    end

    context "when the automate hash does not have a default value" do
      let(:default_value) { nil }

      before do
        described_class.stub(:server_timezone).and_return("UTC")
      end

      it_behaves_like "DialogFieldDateControl#normalize_automate_values"

      it "sets the default value" do
        dialog_field.normalize_automate_values(automate_hash)
        expect(dialog_field.read_attribute(:default_value)).to eq(nil)
      end

      it "returns the initial values" do
        Timecop.freeze(2015, 1, 2) do
          expect(dialog_field.normalize_automate_values(automate_hash)).to eq("01/03/2015")
        end
      end
    end
  end

  describe "#script_error_values" do
    let(:dialog_field) { described_class.new }

    it "returns a script error" do
      expect(dialog_field.script_error_values).to eq("<Script error>")
    end
  end

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
