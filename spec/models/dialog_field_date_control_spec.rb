RSpec.describe DialogFieldDateControl do
  describe "#value" do
    let(:dialog_field) { described_class.new(:dynamic => dynamic, :value => value) }

    context "when the value is not blank" do
      let(:value) { "2015-01-03" }

      context "when the field is dynamic" do
        let(:dynamic) { true }

        it "returns the current value" do
          expect(dialog_field.value).to eq("01/03/2015")
        end
      end

      context "when the field is not dynamic" do
        let(:dynamic) { false }

        it "returns the current value" do
          expect(dialog_field.value).to eq("01/03/2015")
        end
      end
    end

    context "when the value is blank" do
      let(:value) { "" }

      before do
        allow(described_class).to receive(:server_timezone).and_return("UTC")
      end

      context "when the field is dynamic" do
        let(:dynamic) { true }

        it "returns tomorrow's date" do
          Timecop.freeze(Time.new(2015, 1, 2, 0, 0, 0, 0)) do
            expect(dialog_field.value).to eq("01/03/2015")
          end
        end
      end

      context "when the field is not dynamic" do
        let(:dynamic) { false }

        it "returns tomorrow's date" do
          Timecop.freeze(Time.new(2015, 1, 2, 0, 0, 0, 0)) do
            expect(dialog_field.value).to eq("01/03/2015")
          end
        end
      end
    end
  end

  describe "#normalize_automate_values" do
    let(:dialog_field) { described_class.new(:dynamic => true) }
    let(:automate_hash) do
      {
        "value"           => value,
        "show_past_dates" => true,
        "read_only"       => true,
        "description"     => "description"
      }
    end

    before do
      allow(described_class).to receive(:server_timezone).and_return("UTC")
    end

    shared_examples_for "DialogFieldDateControl#normalize_automate_values" do
      before do
        dialog_field.normalize_automate_values(automate_hash)
      end

      it "sets the show_past_dates" do
        expect(dialog_field.show_past_dates).to be_truthy
      end

      it "sets the read_only" do
        expect(dialog_field.read_only).to be_truthy
      end

      it "sets the description" do
        expect(dialog_field.description).to eq("description")
      end
    end

    context "when the automate hash has a value" do
      context "when the value is a string" do
        let(:value) { "01/02/2015" }

        it_behaves_like "DialogFieldDateControl#normalize_automate_values"

        it "returns the value in iso format" do
          expect(dialog_field.normalize_automate_values(automate_hash)).to eq("2015-01-02T00:00:00+00:00")
        end
      end

      context "when the value is a date object" do
        let(:value) { Time.utc(2015, 1, 2) }

        it_behaves_like "DialogFieldDateControl#normalize_automate_values"

        it "returns the value in iso format" do
          expect(dialog_field.normalize_automate_values(automate_hash)).to eq("2015-01-02T00:00:00+00:00")
        end
      end

      context "when the value is not a proper date format" do
        let(:value) { "not a date" }

        it_behaves_like "DialogFieldDateControl#normalize_automate_values"

        it "returns the initial values" do
          Timecop.freeze(2015, 1, 2) do
            expect(dialog_field.normalize_automate_values(automate_hash)).to eq("01/03/2015")
          end
        end
      end
    end

    context "when the automate hash does not have a value" do
      let(:value) { nil }

      it_behaves_like "DialogFieldDateControl#normalize_automate_values"

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

  describe "#refresh_json_value" do
    let(:dialog_field) { described_class.new(:read_only => true) }

    before do
      allow(DynamicDialogFieldValueProcessor).to receive(:values_from_automate).with(dialog_field).and_return("2015-01-02")
    end

    it "returns the values from the value processor" do
      expect(dialog_field.refresh_json_value).to eq(:date => "01/02/2015", :read_only => true, :visible => true)
    end

    it "assigns the processed value to value" do
      dialog_field.refresh_json_value
      expect(dialog_field.value).to eq("01/02/2015")
    end
  end

  describe "#automate_output_value" do
    let(:dialog_field) { described_class.new(:value => value) }

    context "when the dialog_field is blank" do
      let(:value) { "" }

      it "returns nil" do
        expect(dialog_field.automate_output_value).to be_nil
      end
    end

    context "when the dialog_field has a value" do
      context "when the value is a date formatted in ISO" do
        let(:value) { "2013-08-07" }

        it "returns the date in ISO format" do
          expect(dialog_field.automate_output_value).to eq("2013-08-07")
        end
      end

      context "when the value is a date formatted in %m/%d/%Y" do
        let(:value) { "08/07/2013" }

        it "returns the date in ISO format" do
          expect(dialog_field.automate_output_value).to eq("2013-08-07")
        end
      end
    end
  end

  context "#show_past_dates" do
    it "default" do
      expect(subject.show_past_dates).to eq(false)
    end

    it "when true" do
      subject.show_past_dates = true
      expect(subject.options[:show_past_dates]).to be_truthy
      expect(subject.show_past_dates).to be_truthy
    end

    it "when false" do
      subject.show_past_dates = false
      expect(subject.options[:show_past_dates]).to be_falsey
      expect(subject.show_past_dates).to be_falsey
    end
  end

  describe "#trigger_automate_value_updates" do
    let(:dialog_field) { described_class.new }

    before do
      allow(DynamicDialogFieldValueProcessor).to receive(:values_from_automate).with(dialog_field).and_return(
        "2015-01-02"
      )
    end

    it "returns the values from the value processor" do
      expect(dialog_field.trigger_automate_value_updates).to eq("2015-01-02")
    end
  end
end
