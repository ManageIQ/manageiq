RSpec.describe DialogFieldDropDownList do
  context "dialog_field_drop_down_list" do
    let(:data_type) { "string" }
    let(:sort_by) { :description }
    let(:sort_order) { :ascending }
    let(:df) { FactoryBot.create(:dialog_field_sorted_item, :label => 'drop_down_list', :name => 'drop_down_list', :data_type => data_type, :sort_by => sort_by, :sort_order => sort_order) }

    describe "#sort_by" do
      it "allows setters and getters" do
        expect(df.sort_by).to eq(:description)
        df.sort_by = :none
        expect(df.sort_by).to eq(:none)
        df.sort_by = :value
        expect(df.sort_by).to eq(:value)
        expect { df.sort_by = :data }.to raise_error(RuntimeError)
        expect(df.sort_by).to eq(:value)
      end
    end

    describe "#sort_order" do
      it "allows setters and getters" do
        expect(df.sort_order).to eq(:ascending)
        df.sort_order = :descending
        expect(df.sort_order).to eq(:descending)
        expect { df.sort_order = :mixed }.to raise_error(RuntimeError)
        expect(df.sort_order).to eq(:descending)
      end
    end

    describe "sorting #values" do
      before do
        df.values = [%w[2 Y], %w[1 Z], %w[3 X]]
      end

      context "when the data type is a string" do
        let(:data_type) { "string" }

        context "when sorting by description" do
          context "when sorting ascending" do
            it "returns the sorted values with a nil option prepended" do
              expect(df.values).to eq([[nil, "<None>"], %w[3 X], %w[2 Y], %w[1 Z]])
            end
          end

          context "when sorting descending" do
            let(:sort_order) { :descending }

            it "returns the sorted values with a nil option prepended" do
              expect(df.values).to eq([[nil, "<None>"], %w[1 Z], %w[2 Y], %w[3 X]])
            end
          end
        end

        context "when sorting by value" do
          let(:sort_by) { :value }

          context "when sorting ascending" do
            it "returns the sorted values with a nil option prepended" do
              expect(df.values).to eq([[nil, "<None>"], %w[1 Z], %w[2 Y], %w[3 X]])
            end
          end

          context "when sorting descending" do
            let(:sort_order) { :descending }

            it "returns the sorted values with a nil option prepended" do
              expect(df.values).to eq([[nil, "<None>"], %w[3 X], %w[2 Y], %w[1 Z]])
            end
          end
        end

        context "when sorting by none" do
          let(:sort_by) { :none }

          context "when sorting ascending" do
            it "returns the unsorted values with a nil option prepended" do
              expect(df.values).to eq([[nil, "<None>"], %w[2 Y], %w[1 Z], %w[3 X]])
            end
          end

          context "when sorting descending" do
            let(:sort_order) { :descending }

            it "returns the unsorted values with a nil option prepended" do
              expect(df.values).to eq([[nil, "<None>"], %w[2 Y], %w[1 Z], %w[3 X]])
            end
          end
        end
      end

      context "when the data type is an integer" do
        let(:data_type) { "integer" }

        context "when sorting by value" do
          let(:sort_by) { :value }

          context "when sorting ascending" do
            it "returns the sorted values with a nil option prepended" do
              expect(df.values).to eq([[nil, "<None>"], %w[1 Z], %w[2 Y], %w[3 X]])
            end
          end

          context "when sorting descending" do
            let(:sort_order) { :descending }

            it "returns the sorted values with a nil option prepended" do
              expect(df.values).to eq([[nil, "<None>"], %w[3 X], %w[2 Y], %w[1 Z]])
            end
          end
        end

        context "when sorting by none" do
          let(:sort_by) { :none }

          context "when sorting ascending" do
            it "returns the unsorted values with a nil option prepended" do
              expect(df.values).to eq([[nil, "<None>"], %w[2 Y], %w[1 Z], %w[3 X]])
            end
          end

          context "when sorting descending" do
            let(:sort_order) { :descending }

            it "returns the unsorted values with a nil option prepended" do
              expect(df.values).to eq([[nil, "<None>"], %w[2 Y], %w[1 Z], %w[3 X]])
            end
          end
        end
      end
    end

    it "#automate_key_name" do
      expect(df.automate_key_name).to eq("dialog_drop_down_list")
    end
  end

  describe "#initialize_with_given_value" do
    context "when the dialog field forces multi values" do
      let(:dialog_field) do
        described_class.new(:default_value => default_value, :options => {:force_multi_value => true}, :dynamic => true)
      end
      let(:values) { [%w[test test], %w[test2 test2]] }
      let(:default_value) { "test2" }

      before do
        allow(DynamicDialogFieldValueProcessor).to receive(:values_from_automate).with(dialog_field).and_return(values)
      end

      context "given value is a string" do
        it "uses the given value as the default" do
          dialog_field.initialize_with_given_value("test")
          expect(dialog_field.default_value).to eq(["test"].to_json)
        end
      end

      context "given value is an array" do
        it "uses the given value as the default" do
          dialog_field.initialize_with_given_value(["test"])
          expect(dialog_field.default_value).to eq(["test"].to_json)
        end
      end

      context "given value is nil" do
        it "uses the given value as the default" do
          dialog_field.initialize_with_given_value(nil)
          expect(dialog_field.default_value).to eq(nil)
        end
      end
    end
  end

  describe "#refresh_json_value" do
    let(:dialog_field) { described_class.new(:dynamic => dynamic, :read_only => true) }

    context "dynamic" do
      let(:dynamic) { true }
      context "array" do
        context "included" do
          # TODO
        end
        context "not-included" do
          # TODO
        end
      end

      context "not-array" do
        before do
          allow(DynamicDialogFieldValueProcessor).to receive(:values_from_automate).with(dialog_field).and_return(
            [["123", 456], ["789", 101]]
          )
          dialog_field.value = "123"
        end

        it "sets the value" do
          dialog_field.refresh_json_value("789")
          expect(dialog_field.value).to eq("789")
        end

        it "returns the values from automate" do
          expect(dialog_field.refresh_json_value("789")).to eq(
            :refreshed_values => [["789", 101], ["123", 456]],
            :checked_value    => "789",
            :read_only        => true,
            :visible          => true
          )
        end
      end
    end

    context "non-dynamic" do
      let(:dynamic) { false }
      context "array" do
        context "included" do
          # TODO
        end
        context "not-included" do
          # TODO
        end
      end

      context "not-array" do
        context "when the dialog_field is not dynamic" do
          let(:dynamic) { false }

          before do
            dialog_field.values = [["123", 456], ["789", 101]]
            dialog_field.value = "123"
          end

          it "sets the value" do
            dialog_field.refresh_json_value("789")
            expect(dialog_field.value).to eq("789")
          end

          it "returns the values" do
            expect(dialog_field.refresh_json_value("789")).to eq(
              :refreshed_values => [[nil, "<None>"], ["789", 101], ["123", 456]],
              :checked_value    => "789",
              :read_only        => true,
              :visible          => true
            )
          end
        end
      end
    end
  end

  describe "#values" do
    let(:dialog_field) { described_class.new(:dynamic => dynamic, :data_type => data_type, :sort_by => :value) }
    let(:data_type) { "string" }

    context "when the dialog_field is dynamic" do
      let(:dynamic) { true }

      context "when the raw values are already set" do
        before do
          dialog_field.instance_variable_set(:@raw_values, %w[potato potato])
        end

        it "returns the raw values" do
          expect(dialog_field.values).to eq(%w[potato potato])
        end
      end

      context "when the raw values are not already set" do
        context "when the values returned are strings" do
          before do
            allow(DynamicDialogFieldValueProcessor).to receive(:values_from_automate).with(dialog_field).and_return(%w[automate values])
          end

          it "returns the values from automate" do
            expect(dialog_field.values).to eq(%w[automate values])
          end

          context "when the values returned contain a nil" do
            before do
              allow(DynamicDialogFieldValueProcessor).to receive(:values_from_automate).with(dialog_field).and_return(
                [[nil, "Choose something!"], %w[1 one], %w[2 two], %w[abc def]]
              )
            end

            context "when it is a multiselect" do
              before do
                dialog_field.force_multi_value = true
              end

              context "when the default value is included" do
                before do
                  dialog_field.default_value = "[\"1\"]"
                end

                it "keeps the default" do
                  dialog_field.values
                  expect(dialog_field.default_value).to eq("[\"1\"]")
                end
              end

              context "when the default value is included but is not an array" do
                before do
                  dialog_field.default_value = "1"
                end

                it "keeps the default" do
                  dialog_field.values
                  expect(dialog_field.default_value).to eq("[\"1\"]")
                end
              end

              context "when the default value is included but is not valid json" do
                before do
                  dialog_field.default_value = "abc"
                end

                it "keeps the default" do
                  dialog_field.values
                  expect(dialog_field.default_value).to eq("[\"abc\"]")
                end
              end

              context "when the default value is not included" do
                before do
                  dialog_field.default_value = "[\"3\"]"
                end

                it "selects nothing" do
                  dialog_field.values
                  expect(dialog_field.default_value).to eq("[]")
                end
              end
            end

            it "returns the values from automate" do
              expect(dialog_field.values).to eq([[nil, "Choose something!"], %w[1 one], %w[2 two], %w[abc def]])
            end
          end
        end

        context "when the values returned are integers" do
          before do
            allow(DynamicDialogFieldValueProcessor).to receive(:values_from_automate).with(dialog_field).and_return(
              0  => "zero",
              5  => "five",
              10 => "ten"
            )
            dialog_field.default_value = "5"
          end

          context "when the data type is integer" do
            let(:data_type) { "integer" }

            it "returns the values from automate, sorted" do
              expect(dialog_field.values).to eq([[0, "zero"], [5, "five"], [10, "ten"]])
            end

            it "sets the value to the default value" do
              dialog_field.values
              expect(dialog_field.value).to eq(5)
            end
          end

          context "when the data type is string" do
            it "returns the values from automate, sorted by string comparison" do
              expect(dialog_field.values).to eq([[0, "zero"], [10, "ten"], [5, "five"]])
            end

            it "sets the value to the default value as a string" do
              dialog_field.values
              expect(dialog_field.value).to eq("5")
            end
          end
        end
      end
    end

    context "when the dialog_field is not dynamic" do
      let(:dynamic) { false }

      context "when the raw values are already set" do
        before do
          dialog_field.instance_variable_set(:@raw_values, [%w[potato potato]])
        end

        context 'and this is a multiselect' do
          before do
            dialog_field.force_multi_value = true
          end

          it "returns the raw values without a nil option" do
            expect(dialog_field.values).to eq([%w[potato potato]])
          end
        end

        context 'and this is a single select' do
          before do
            dialog_field.force_multi_value = false
          end

          it "returns the raw values with a nil option" do
            expect(dialog_field.values).to eq([[nil, "<None>"], %w[potato potato]])
          end
        end
      end

      context "dialog field dropdown without options hash" do
        let(:df) { FactoryBot.create(:dialog_field_drop_down_list, :name => 'test drop down') }

        describe "#force_multi_value" do
          context "when force_multi_value is present" do
            context "when force_multi_value is null" do
              it "multivalue false" do
                expect(df.force_multi_value).to be_falsey
              end
            end

            context "when force_multi_value is not null" do
              context "when force_multi_value is truthy" do
                it "multivalue true" do
                  df.force_multi_value = true
                  expect(df.force_multi_value).to be_truthy
                end
              end

              context "when force_multi_value is falsy" do
                it "multivalue false" do
                  expect(df.force_multi_value).to be_falsey
                end
              end
            end
          end

          context "when force_multi_value is not present" do
            it "multivalue false" do
              expect(df.force_multi_value).to be_falsey
            end
          end
        end
      end

      context "dialog field dropdown with options hash" do
        let(:df) { FactoryBot.create(:dialog_field_drop_down_list, :name => 'test drop down', :options => {:force_multi_value => true}) }
        it "#force_multi_value" do
          expect(df.force_multi_value).to be_truthy
        end
      end

      context "when the raw values are not already set" do
        before do
          dialog_field.values = [%w[original values]]
        end

        context 'and this is a multiselect' do
          before do
            dialog_field.force_multi_value = true
          end

          it "returns the values" do
            expect(dialog_field.values).to eq([%w[original values]])
          end
        end

        context 'and this is a single select' do
          before do
            dialog_field.force_multi_value = false
          end

          it "returns the values including nil" do
            expect(dialog_field.values).to eq([[nil, "<None>"], %w[original values]])
          end
        end
      end
    end
  end

  describe "#trigger_automate_value_updates" do
    let(:dialog_field) { described_class.new(:dynamic => dynamic) }

    context "when the dialog_field is dynamic" do
      let(:dynamic) { true }

      before do
        allow(DynamicDialogFieldValueProcessor).to receive(:values_from_automate).with(dialog_field).and_return(
          %w[automate values]
        )
      end

      context "when the raw values are already set" do
        before do
          dialog_field.instance_variable_set(:@raw_values, %w[potato potato])
        end

        it "updates with the values from automate" do
          expect(dialog_field.trigger_automate_value_updates).to eq(%w[automate values])
        end
      end

      context "when the raw values are not already set" do
        it "returns the values from automate" do
          expect(dialog_field.trigger_automate_value_updates).to eq(%w[automate values])
        end
      end
    end

    context "when the dialog_field is not dynamic" do
      let(:dynamic) { false }

      context "when the raw values are already set" do
        before do
          dialog_field.instance_variable_set(:@raw_values, %w[potato potato])
          dialog_field.values = [%w[original values]]
        end

        it "returns the raw values" do
          expect(dialog_field.trigger_automate_value_updates).to eq([[nil, "<None>"], %w[original values]])
        end
      end

      context "when the raw values are not already set" do
        before do
          dialog_field.values = [%w[original values]]
        end

        it "returns the values" do
          expect(dialog_field.trigger_automate_value_updates).to eq([[nil, "<None>"], %w[original values]])
        end

        it "sets up the default value" do
          dialog_field.trigger_automate_value_updates
          expect(dialog_field.default_value).to eq(nil)
        end
      end

      context "when the raw values are nil" do
        before do
          dialog_field.values = nil
        end

        it "sets the default value to nil without blowing up" do
          dialog_field.trigger_automate_value_updates
          expect(dialog_field.default_value).to eq(nil)
        end
      end
    end
  end
end
