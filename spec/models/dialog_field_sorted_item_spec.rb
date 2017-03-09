describe DialogFieldSortedItem do
  describe "#initialize_with_values" do
    let(:dialog_field) do
      described_class.new(
        :name                => "potato_name",
        :default_value       => "test2",
        :dynamic             => true,
        :load_values_on_init => load_values_on_init,
        :show_refresh_button => show_refresh_button,
        :values              => [%w(test test), %w(test2 test2)]
      )
    end

    context "when show_refresh_button is true" do
      let(:show_refresh_button) { true }

      context "when load_values_on_init is true" do
        let(:load_values_on_init) { true }

        context "when the dialog values match the automate key name" do
          let(:dialog_values) { {"dialog_potato_name" => "dialog potato value"} }

          it "uses the values given" do
            dialog_field.initialize_with_values(dialog_values)
            expect(dialog_field.value).to eq("dialog potato value")
          end
        end

        context "when the dialog values match the dialog name" do
          let(:dialog_values) { {"potato_name" => "potato value"} }

          it "uses the values given" do
            dialog_field.initialize_with_values(dialog_values)
            expect(dialog_field.value).to eq("potato value")
          end
        end

        context "when the values from the passed in dialog values do not match either the automate or dialog name" do
          let(:dialog_values) { {"not_potato_name" => "not potato value"} }

          it "defaults to nil" do
            dialog_field.initialize_with_values(dialog_values)
            expect(dialog_field.value).to eq(nil)
          end
        end
      end

      context "when load_values_on_init is false" do
        let(:load_values_on_init) { false }
        let(:dialog_values) { "potato" }

        it "sets the raw values to the initial values" do
          dialog_field.initialize_with_values(dialog_values)
          expect(dialog_field.instance_variable_get(:@raw_values)).to eq([[nil, "<None>"]])
        end
      end
    end

    context "when show_refresh_button is false" do
      let(:show_refresh_button) { false }

      context "when load_values_on_init is true" do
        let(:load_values_on_init) { true }

        context "when the dialog values match the automate key name" do
          let(:dialog_values) { {"dialog_potato_name" => "dialog potato value"} }

          it "uses the values given" do
            dialog_field.initialize_with_values(dialog_values)
            expect(dialog_field.value).to eq("dialog potato value")
          end
        end

        context "when the dialog values match the dialog name" do
          let(:dialog_values) { {"potato_name" => "potato value"} }

          it "uses the values given" do
            dialog_field.initialize_with_values(dialog_values)
            expect(dialog_field.value).to eq("potato value")
          end
        end

        context "when the values from the passed in dialog values do not match either the automate or dialog name" do
          let(:dialog_values) { {"not_potato_name" => "not potato value"} }

          context "when the default value does not exist in the list of options" do
            let(:default_value) { "default value" }

            it "defaults to nil" do
              dialog_field.initialize_with_values(dialog_values)
              expect(dialog_field.value).to eq(nil)
            end
          end
        end
      end

      context "when load_values_on_init is false" do
        let(:load_values_on_init) { false }

        context "when the dialog values match the automate key name" do
          let(:dialog_values) { {"dialog_potato_name" => "dialog potato value"} }

          it "uses the values given" do
            dialog_field.initialize_with_values(dialog_values)
            expect(dialog_field.value).to eq("dialog potato value")
          end
        end

        context "when the dialog values match the dialog name" do
          let(:dialog_values) { {"potato_name" => "potato value"} }

          it "uses the values given" do
            dialog_field.initialize_with_values(dialog_values)
            expect(dialog_field.value).to eq("potato value")
          end
        end

        context "when the values from the passed in dialog values do not match either the automate or dialog name" do
          let(:dialog_values) { {"not_potato_name" => "not potato value"} }

          it "defaults to nil" do
            dialog_field.initialize_with_values(dialog_values)
            expect(dialog_field.value).to eq(nil)
          end
        end
      end
    end
  end

  describe "#values" do
    let(:dialog_field) do
      described_class.new(
        :default_value => default_value,
        :dynamic       => dynamic,
        :required      => required,
        :sort_by       => :none,
        :values        => values
      )
    end
    let(:values) { [%w(test test), %w(abc abc)] }
    let(:required) { false }

    context "when the field is dynamic" do
      let(:dynamic) { true }

      before do
        allow(DynamicDialogFieldValueProcessor).to receive(:values_from_automate).with(dialog_field).and_return(values)
      end

      context "when the default_value is included in the list of returned values" do
        let(:default_value) { "abc" }

        it "sets the default value" do
          dialog_field.values
          expect(dialog_field.default_value).to eq("abc")
        end

        it "sets the value to the default value" do
          dialog_field.values
          expect(dialog_field.default_value).to eq("abc")
        end
      end

      context "when the default_value is not included in the list of returned values" do
        let(:default_value) { "123" }

        it "sets the default value to the first value" do
          dialog_field.values
          expect(dialog_field.default_value).to eq("test")
        end

        it "sets the value to the default value" do
          dialog_field.values
          expect(dialog_field.value).to eq("test")
        end
      end
    end

    context "when the field is not dynamic" do
      let(:dynamic) { false }
      let(:default_value) { "abc" }

      context "when the field is required" do
        let(:required) { true }

        it "returns the values with the first option being a nil 'Choose' option" do
          expect(dialog_field.values).to eq([[nil, "<Choose>"], %w(test test), %w(abc abc)])
        end
      end

      context "when the field is not required" do
        it "returns the values with the first option being a nil 'None' option" do
          expect(dialog_field.values).to eq([[nil, "<None>"], %w(test test), %w(abc abc)])
        end
      end
    end
  end

  describe "#get_default_value" do
    let(:dialog_field) { described_class.new(:default_value => default_value, :values => values) }
    let(:values) { [%w(value1 text1), %w(value2 text2)] }

    context "when the default value is set to nil" do
      let(:default_value) { nil }

      it "returns nil as the default value" do
        expect(dialog_field.get_default_value).to eq(nil)
      end
    end

    context "when the default value exists" do
      context "when the default value matches with a value in the list" do
        let(:default_value) { "value2" }

        it "returns the matched value" do
          expect(dialog_field.get_default_value).to eq("value2")
        end
      end

      context "when the default value does not match with a value in the list" do
        let(:default_value) { "value3" }

        it "returns nil" do
          expect(dialog_field.get_default_value).to eq(nil)
        end
      end
    end
  end

  describe "#script_error_values" do
    let(:dialog_field) { described_class.new }

    it "returns the script error values" do
      expect(dialog_field.script_error_values).to eq([[nil, "<Script error>"]])
    end
  end

  describe "#normalize_automate_values" do
    let(:dialog_field) { DialogFieldRadioButton.new }
    let(:automate_hash) do
      {
        "sort_by"       => "none",
        "sort_order"    => "descending",
        "data_type"     => "datatype",
        "default_value" => "default",
        "required"      => true,
        "read_only"     => true,
        "values"        => values
      }
    end

    shared_examples_for "DialogFieldSortedItem#normalize_automate_values" do
      before do
        dialog_field.normalize_automate_values(automate_hash)
      end

      it "sets the sort_by" do
        expect(dialog_field.sort_by).to eq(:none)
      end

      it "sets the sort_order" do
        expect(dialog_field.sort_order).to eq(:descending)
      end

      it "sets the data_type" do
        expect(dialog_field.data_type).to eq("datatype")
      end

      it "sets the default_value" do
        expect(dialog_field.default_value).to eq("default")
      end

      it "sets the required" do
        expect(dialog_field.required).to be_truthy
      end

      it "sets the read_only" do
        expect(dialog_field.read_only).to be_truthy
      end
    end

    context "when the automate hash values passed in are blank" do
      let(:values) { nil }

      it_behaves_like "DialogFieldSortedItem#normalize_automate_values"

      it "returns the initial values of the dialog field" do
        expect(dialog_field.normalize_automate_values(automate_hash)).to eq([[nil, "<None>"]])
      end
    end

    context "when the automate hash values passed in are not blank" do
      let(:values) { {"lol" => "123"} }

      it_behaves_like "DialogFieldSortedItem#normalize_automate_values"

      it "normalizes the values to an array" do
        expect(dialog_field.normalize_automate_values(automate_hash)).to eq([%w(lol 123)])
      end
    end
  end
end
