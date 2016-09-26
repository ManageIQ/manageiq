describe DialogFieldSortedItem do
  let(:df) { FactoryGirl.build(:dialog_field_sorted_item, :label => 'dialog_field', :name => 'dialog_field') }

  describe "#initialize_with_values" do
    let(:dialog_field) do
      described_class.new(
        :name                => "potato_name",
        :default_value       => default_value,
        :load_values_on_init => load_values_on_init,
        :show_refresh_button => show_refresh_button,
        :values              => [%w(test test), %w(test2 test2)]
      )
    end
    let(:default_value) { "test2" }

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

          context "when the default value does not exist in the list of options" do
            let(:default_value) { "default value" }

            it "uses the default value of the dialog field" do
              dialog_field.initialize_with_values(dialog_values)
              expect(dialog_field.value).to eq("test")
            end
          end

          context "when the default value does exist in the list of options" do
            it "uses the default value of the dialog field" do
              dialog_field.initialize_with_values(dialog_values)
              expect(dialog_field.value).to eq("test2")
            end
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

            it "uses the default value of the dialog field" do
              dialog_field.initialize_with_values(dialog_values)
              expect(dialog_field.value).to eq("test")
            end
          end

          context "when the default value does exist in the list of options" do
            it "uses the default value of the dialog field" do
              dialog_field.initialize_with_values(dialog_values)
              expect(dialog_field.value).to eq("test2")
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

          context "when the default value does not exist in the list of options" do
            let(:default_value) { "default value" }

            it "uses the default value of the dialog field" do
              dialog_field.initialize_with_values(dialog_values)
              expect(dialog_field.value).to eq("test")
            end
          end

          context "when the default value does exist in the list of options" do
            it "uses the default value of the dialog field" do
              dialog_field.initialize_with_values(dialog_values)
              expect(dialog_field.value).to eq("test2")
            end
          end
        end
      end
    end
  end

  describe "#get_default_value" do
    it "returns the first value when no default and only a single value is available" do
      df.values = [%w(value1 text1)]
      expect(df.get_default_value).to eq("value1")
    end

    it "returns the first value when no default and multiple values are available" do
      df.values = [%w(value1 text1), %w(value2 text2)]
      expect(df.get_default_value).to eq("value1")
    end
  end

  describe "#script_error_values" do
    it "returns the script error values" do
      expect(df.script_error_values).to eq([[nil, "<Script error>"]])
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
        expect(dialog_field.normalize_automate_values(automate_hash)).to eq([["", "<None>"]])
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
