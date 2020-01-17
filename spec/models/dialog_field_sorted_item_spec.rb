RSpec.describe DialogFieldSortedItem do
  describe "#initialize_value_context" do
    let(:dialog_field) do
      described_class.new(
        :name                => "potato_name",
        :default_value       => default_value,
        :dynamic             => true,
        :load_values_on_init => load_values_on_init,
        :show_refresh_button => show_refresh_button,
        :values              => [%w(test test), %w(test2 test2)]
      )
    end
    let(:default_value) { "test2" }
    let(:automate_values) { [%w(test1 test1), %w(test2 test2), %w(test3 test3)] }
    let(:empty_values) { [[nil, "<None>"]] }

    before do
      allow(DynamicDialogFieldValueProcessor).to receive(:values_from_automate).and_return(automate_values)
    end

    context "when show_refresh_button is true" do
      let(:show_refresh_button) { true }

      context "when load_values_on_init is true" do
        let(:load_values_on_init) { true }

        context "when the default_value is not included in the list of values" do
          let(:default_value) { "test4" }

          it "uses the first value as the default" do
            dialog_field.initialize_value_context
            expect(dialog_field.default_value).to eq("test1")
          end

          it "sets the values to what should be returned from automate" do
            dialog_field.initialize_value_context
            expect(dialog_field.extract_dynamic_values).to eq(automate_values)
          end
        end

        context "when the default_value is included in the list of values" do
          let(:default_value) { "test2" }

          it "uses the given value as the default" do
            dialog_field.initialize_value_context
            expect(dialog_field.default_value).to eq("test2")
          end

          it "sets the values to what should be returned from automate" do
            dialog_field.initialize_value_context
            expect(dialog_field.extract_dynamic_values).to eq(automate_values)
          end
        end
      end

      context "when load_values_on_init is false" do
        let(:load_values_on_init) { false }
        let(:dialog_values) { "potato" }

        it "sets the raw values to the initial values" do
          dialog_field.initialize_value_context
          expect(dialog_field.instance_variable_get(:@raw_values)).to eq([[nil, "<None>"]])
        end
      end
    end

    context "when show_refresh_button is false" do
      let(:show_refresh_button) { false }

      context "when load_values_on_init is true" do
        let(:load_values_on_init) { true }

        context "when the default_value is not included in the list of values" do
          let(:default_value) { "test4" }

          it "uses the first value as the default" do
            dialog_field.initialize_value_context
            expect(dialog_field.default_value).to eq("test1")
          end

          it "sets the values to what should be returned from automate" do
            dialog_field.initialize_value_context
            expect(dialog_field.extract_dynamic_values).to eq(automate_values)
          end
        end

        context "when the default_value is included in the list of values" do
          let(:default_value) { "test2" }

          it "uses the given value as the default" do
            dialog_field.initialize_value_context
            expect(dialog_field.default_value).to eq("test2")
          end

          it "sets the values to what should be returned from automate" do
            dialog_field.initialize_value_context
            expect(dialog_field.extract_dynamic_values).to eq(automate_values)
          end
        end
      end

      context "when load_values_on_init is false" do
        let(:load_values_on_init) { false }

        context "when the default_value is not included in the list of values" do
          let(:default_value) { "test4" }

          it "uses the given value as the default" do
            dialog_field.initialize_value_context
            expect(dialog_field.default_value).to eq("test4")
          end

          it "sets the values to empty" do
            dialog_field.initialize_value_context
            expect(dialog_field.extract_dynamic_values).to eq(empty_values)
          end
        end

        context "when the default_value is included in the list of values" do
          let(:default_value) { "test2" }

          it "uses the given value as the default" do
            dialog_field.initialize_value_context
            expect(dialog_field.default_value).to eq("test2")
          end

          it "sets the values to empty" do
            dialog_field.initialize_value_context
            expect(dialog_field.extract_dynamic_values).to eq(empty_values)
          end
        end
      end
    end
  end

  describe "#initialize_with_given_value" do
    let(:dialog_field) do
      described_class.new(:default_value => default_value, :dynamic => true)
    end
    let(:values) { [%w(test test), %w(test2 test2)] }
    let(:default_value) { "test2" }

    before do
      allow(DynamicDialogFieldValueProcessor).to receive(:values_from_automate).with(dialog_field).and_return(values)
    end

    it "uses the given value as the default" do
      dialog_field.initialize_with_given_value("test")
      expect(dialog_field.default_value).to eq("test")
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

      context "when the force_multi_value is set to false" do
        let(:default_value) { "abc" }
        before do
          allow(dialog_field).to receive(:force_multi_value).and_return(false)
        end

        it "sets the default_value" do
          dialog_field.values
          expect(dialog_field.default_value).to eq("abc")
        end
      end

      context "when the default_value is included in the list of returned values" do
        before do
          allow(dialog_field).to receive(:force_multi_value).and_return(false)
        end

        let(:default_value) { "abc" }

        it "sets the value to the default value" do
          dialog_field.values
          expect(dialog_field.default_value).to eq("abc")
        end
      end

      context "when the default_value is not included in the list of returned values" do
        before do
          allow(dialog_field).to receive(:force_multi_value).and_return(false)
        end

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

      context "when the data type is not integer" do
        context "when the default_value is set" do
          let(:default_value) { "abc" }

          context "when the field is required" do
            let(:required) { true }

            it "returns the values without the first option being a nil option" do
              expect(dialog_field.values).to eq([%w(test test), %w(abc abc)])
            end
          end

          context "when the field is not required" do
            it "returns the values with the first option being a nil 'None' option" do
              expect(dialog_field.values).to eq([[nil, "<None>"], %w(test test), %w(abc abc)])
            end

            context "when the values are in a seemingly random order" do
              let(:values) { [%w(3 Three), %w(1 One), %w(2 Two)] }
              before do
                dialog_field.options[:sort_by] = "none"
              end

              it "does not attempt to sort them" do
                expect(dialog_field.values).to eq([[nil, "<None>"], %w(3 Three), %w(1 One), %w(2 Two)])
              end
            end
          end
        end
      end

      context "when the data type is an integer" do
        let(:data_type) { "integer" }

        before do
          dialog_field.data_type = data_type
        end

        context "when there is a default value that matches a value in the values list" do
          let(:default_value) { "2" }
          let(:values) { [%w(1 1), %w(2 2), %w(3 3)] }

          it "sets the default value to the matching value" do
            dialog_field.values
            expect(dialog_field.default_value).to eq("2")
          end

          it "returns the values with the first option being a nil 'None' option" do
            expect(dialog_field.values).to eq([[nil, "<None>"], %w(1 1), %w(2 2), %w(3 3)])
          end
        end

        context "when there is a default value that does not match a value in the values list" do
          let(:default_value) { "4" }
          let(:values) { [%w(1 1), %w(2 2), %w(3 3)] }

          it "sets the default value to nil" do
            dialog_field.values
            expect(dialog_field.default_value).to eq(nil)
          end

          it "returns the values with the first option being a nil 'None' option" do
            expect(dialog_field.values).to eq([[nil, "<None>"], %w(1 1), %w(2 2), %w(3 3)])
          end
        end

        context "when the default value is nil" do
          let(:default_value) { nil }

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
        "description"   => "description",
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

      it "sets the description" do
        expect(dialog_field.description).to eq("description")
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
