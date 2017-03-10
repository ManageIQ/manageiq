describe ApplicationHelper::Dialogs do
  let(:dialog_field) do
    double(
      "DialogField",
      :id                   => "100",
      :read_only            => read_only,
      :trigger_auto_refresh => trigger_auto_refresh
    )
  end
  let(:trigger_auto_refresh) { nil }

  describe "#dialog_dropdown_select_values" do
    let(:dialog_field) { instance_double("DialogFieldDropDownList", :values => values, :type => type) }
    let(:values) { [%w(cat Cat), %w(dog Dog)] }

    context "when the field type includes drop down" do
      let(:type) { "BananaDropDown" }

      it "returns the values collected and reversed" do
        expect(helper.dialog_dropdown_select_values(dialog_field, nil)).to eq(values.collect(&:reverse))
      end
    end

    context "when the field type includes tag control" do
      let(:type) { "BananaTagControl" }

      it "returns the values with the passed in category tags" do
        expect(helper.dialog_dropdown_select_values(dialog_field, nil, %w(category tags))).to eq(%w(category tags))
      end
    end
  end

  describe "#textbox_tag_options" do
    let(:auto_refresh_options_hash) do
      {
        :tab_index                       => "100",
        :group_index                     => "200",
        :field_index                     => "300",
        :auto_refreshable_field_indicies => [1, 2, 3],
        :current_index                   => 123,
        :trigger                         => "true"
      }
    end

    context "when the field is read_only" do
      let(:read_only) { true }

      it "returns the tag options with a disabled true" do
        expect(helper.textbox_tag_options(dialog_field, "url", auto_refresh_options_hash)).to eq(
          :maxlength => 50,
          :class     => "dynamic-text-box-100 form-control",
          :disabled  => true,
          :title     => "This element is disabled because it is read only"
        )
      end
    end

    context "when the dialog field is not read only" do
      let(:read_only) { false }

      context "when the dialog field does not trigger auto refresh" do
        let(:trigger_auto_refresh) { false }

        it "returns the tag options with a data-miq-observe" do
          expect(helper.textbox_tag_options(dialog_field, "url", auto_refresh_options_hash)).to eq(
            :maxlength         => 50,
            :class             => "dynamic-text-box-100 form-control",
            "data-miq_observe" => '{"url":"url"}'
          )
        end
      end

      context "when the dialog field triggers auto refresh" do
        let(:trigger_auto_refresh) { true }

        it "returns the tag options with a data-miq-observe" do
          expect(helper.textbox_tag_options(dialog_field, "url", auto_refresh_options_hash)).to eq(
            :maxlength         => 50,
            :class             => "dynamic-text-box-100 form-control",
            "data-miq_observe" => {
              :url                             => "url",
              :auto_refresh                    => true,
              :tab_index                       => "100",
              :group_index                     => "200",
              :field_index                     => "300",
              :auto_refreshable_field_indicies => [1, 2, 3],
              :current_index                   => 123,
              :trigger                         => "true"
            }.to_json
          )
        end
      end
    end
  end

  describe "#textarea_tag_options" do
    let(:auto_refresh_options_hash) do
      {
        :tab_index                       => "100",
        :group_index                     => "200",
        :field_index                     => "300",
        :auto_refreshable_field_indicies => [1, 2, 3],
        :current_index                   => 123,
        :trigger                         => "true"
      }
    end

    context "when the field is read_only" do
      let(:read_only) { true }

      it "returns the tag options with a disabled true" do
        expect(helper.textarea_tag_options(dialog_field, "url", auto_refresh_options_hash)).to eq(
          :class    => "dynamic-text-area-100 form-control",
          :size     => "50x6",
          :disabled => true,
          :title    => "This element is disabled because it is read only"
        )
      end
    end

    context "when the dialog field is not read only" do
      let(:read_only) { false }

      context "when the dialog field triggers auto refresh" do
        let(:trigger_auto_refresh) { true }

        it "returns the tag options with a data-miq-observe" do
          expect(helper.textarea_tag_options(dialog_field, "url", auto_refresh_options_hash)).to eq(
            :class             => "dynamic-text-area-100 form-control",
            :size              => "50x6",
            "data-miq_observe" => {
              :url                             => "url",
              :auto_refresh                    => true,
              :tab_index                       => "100",
              :group_index                     => "200",
              :field_index                     => "300",
              :auto_refreshable_field_indicies => [1, 2, 3],
              :current_index                   => 123,
              :trigger                         => "true"
            }.to_json
          )
        end
      end

      context "when the dialog field does not trigger auto refresh" do
        let(:trigger_auto_refresh) { false }

        it "returns the tag options with a data-miq-observe" do
          expect(helper.textarea_tag_options(dialog_field, "url", auto_refresh_options_hash)).to eq(
            :class             => "dynamic-text-area-100 form-control",
            :size              => "50x6",
            "data-miq_observe" => '{"url":"url"}'
          )
        end
      end
    end
  end

  describe "#checkbox_tag_options" do
    let(:auto_refresh_options_hash) do
      {
        :tab_index                       => "100",
        :group_index                     => "200",
        :field_index                     => "300",
        :auto_refreshable_field_indicies => [1, 2, 3],
        :current_index                   => 123,
        :trigger                         => "true"
      }
    end

    context "when the field is read_only" do
      let(:read_only) { true }

      it "returns the tag options with a disabled true" do
        expect(helper.checkbox_tag_options(dialog_field, "url", auto_refresh_options_hash)).to eq(
          :class    => "dynamic-checkbox-100",
          :disabled => true,
          :title    => "This element is disabled because it is read only"
        )
      end
    end

    context "when the dialog field is not read only" do
      let(:read_only) { false }

      context "when the dialog field triggers auto refresh" do
        let(:trigger_auto_refresh) { true }

        it "returns the tag options with a few data-miq attributes" do
          expect(helper.checkbox_tag_options(dialog_field, "url", auto_refresh_options_hash)).to eq(
            :class                      => "dynamic-checkbox-100",
            "data-miq_sparkle_on"       => true,
            "data-miq_sparkle_off"      => true,
            "data-miq_observe_checkbox" => {
              :url                             => "url",
              :auto_refresh                    => true,
              :tab_index                       => "100",
              :group_index                     => "200",
              :field_index                     => "300",
              :auto_refreshable_field_indicies => [1, 2, 3],
              :current_index                   => 123,
              :trigger                         => "true"
            }.to_json
          )
        end
      end

      context "when the dialog field does not trigger auto refresh" do
        let(:trigger_auto_refresh) { false }

        it "returns the tag options with a few data-miq attributes" do
          expect(helper.checkbox_tag_options(dialog_field, "url", auto_refresh_options_hash)).to eq(
            :class                      => "dynamic-checkbox-100",
            "data-miq_sparkle_on"       => true,
            "data-miq_sparkle_off"      => true,
            "data-miq_observe_checkbox" => '{"url":"url"}'
          )
        end
      end
    end
  end

  describe "#date_tag_options" do
    let(:auto_refresh_options_hash) do
      {
        :tab_index                       => "100",
        :group_index                     => "200",
        :field_index                     => "300",
        :auto_refreshable_field_indicies => [1, 2, 3],
        :current_index                   => 123,
        :trigger                         => "true"
      }
    end

    context "when the field is read_only" do
      let(:read_only) { true }

      it "returns the tag options with a disabled true" do
        expect(helper.date_tag_options(dialog_field, "url", auto_refresh_options_hash)).to eq(
          :class    => "css1 dynamic-date-100",
          :readonly => "true",
          :disabled => true,
          :title    => "This element is disabled because it is read only"
        )
      end
    end

    context "when the dialog field is not read only" do
      let(:read_only) { false }

      context "when the dialog field triggers auto refresh" do
        let(:trigger_auto_refresh) { true }

        it "returns the tag options with a few data-miq attributes" do
          expect(helper.date_tag_options(dialog_field, "url", auto_refresh_options_hash)).to eq(
            :class                  => "css1 dynamic-date-100",
            :readonly               => "true",
            "data-miq_observe_date" => {
              :url                             => "url",
              :auto_refresh                    => true,
              :tab_index                       => "100",
              :group_index                     => "200",
              :field_index                     => "300",
              :auto_refreshable_field_indicies => [1, 2, 3],
              :current_index                   => 123,
              :trigger                         => "true"
            }.to_json
          )
        end
      end

      context "when the dialog field does not trigger auto refresh" do
        let(:trigger_auto_refresh) { false }

        it "returns the tag options with a few data-miq attributes" do
          expect(helper.date_tag_options(dialog_field, "url", auto_refresh_options_hash)).to eq(
            :class                  => "css1 dynamic-date-100",
            :readonly               => "true",
            "data-miq_observe_date" => '{"url":"url"}'
          )
        end
      end
    end
  end

  describe "#time_tag_options" do
    let(:auto_refresh_options_hash) do
      {
        :tab_index                       => "100",
        :group_index                     => "200",
        :field_index                     => "300",
        :auto_refreshable_field_indicies => [1, 2, 3],
        :current_index                   => 123,
        :trigger                         => "true"
      }
    end

    context "when the field is read_only" do
      let(:read_only) { true }

      it "returns the tag options with a disabled true" do
        expect(helper.time_tag_options(dialog_field, "url", "hour_or_min", auto_refresh_options_hash)).to eq(
          :class    => "dynamic-date-hour_or_min-100",
          :disabled => true,
          :title    => "This element is disabled because it is read only"
        )
      end
    end

    context "when the dialog field is not read only" do
      let(:read_only) { false }

      context "when the dialog field triggers auto refresh" do
        let(:trigger_auto_refresh) { true }

        it "returns the tag options with a few data-miq attributes" do
          expect(helper.time_tag_options(dialog_field, "url", "hour_or_min", auto_refresh_options_hash)).to eq(
            :class             => "dynamic-date-hour_or_min-100",
            "data-miq_observe" => {
              :url                             => "url",
              :auto_refresh                    => true,
              :tab_index                       => "100",
              :group_index                     => "200",
              :field_index                     => "300",
              :auto_refreshable_field_indicies => [1, 2, 3],
              :current_index                   => 123,
              :trigger                         => "true"
            }.to_json
          )
        end
      end

      context "when the dialog field does not trigger auto refresh" do
        let(:trigger_auto_refresh) { false }

        it "returns the tag options with a few data-miq attributes" do
          expect(helper.time_tag_options(dialog_field, "url", "hour_or_min", auto_refresh_options_hash)).to eq(
            :class             => "dynamic-date-hour_or_min-100",
            "data-miq_observe" => '{"url":"url"}'
          )
        end
      end
    end
  end

  describe "#drop_down_options" do
    context "when the field is read_only" do
      let(:read_only) { true }

      it "returns the tag options with a disabled true" do
        expect(helper.drop_down_options(dialog_field, "url")).to eq(
          :class    => "dynamic-drop-down-100 selectpicker",
          :disabled => true,
          :title    => "This element is disabled because it is read only"
        )
      end
    end

    context "when the dialog field is not read only" do
      let(:read_only) { false }

      context "when the dialog field triggers auto refresh" do
        let(:trigger_auto_refresh) { true }

        it "returns the tag options with a few data-miq attributes" do
          expect(helper.drop_down_options(dialog_field, "url")).to eq(
            :class                 => "dynamic-drop-down-100 selectpicker",
            "data-miq_sparkle_on"  => true,
            "data-miq_sparkle_off" => true,
            "data-live-search"     => true
          )
        end
      end

      context "when the dialog field does not trigger auto refresh" do
        let(:trigger_auto_refresh) { false }

        it "returns the tag options with a few data-miq attributes" do
          expect(helper.drop_down_options(dialog_field, "url")).to eq(
            :class                 => "dynamic-drop-down-100 selectpicker",
            "data-miq_sparkle_on"  => true,
            "data-miq_sparkle_off" => true,
            "data-live-search"     => true
          )
        end
      end
    end
  end

  describe "#radio_options" do
    let(:dialog_field) do
      double(
        "DialogField",
        :default_value        => "some_value",
        :name                 => "field_name",
        :id                   => "100",
        :read_only            => read_only,
        :trigger_auto_refresh => trigger_auto_refresh,
        :value                => value
      )
    end

    context "when the field is read_only" do
      let(:read_only) { true }
      let(:selected_value) { "some_value" }

      context "when the current value is equal to the default value" do
        let(:value) { "some_value" }

        it "returns the tag options with a disabled true and checked" do
          expect(helper.radio_options(dialog_field, "url", value, selected_value)).to eq(
            :type     => "radio",
            :class    => "100",
            :value    => "some_value",
            :name     => "field_name",
            :checked  => '',
            :disabled => true,
            :title    => "This element is disabled because it is read only"
          )
        end
      end

      context "when the current value is not equal to the default value" do
        let(:value) { "bogus" }

        it "returns the tag options with a disabled true and checked" do
          expect(helper.radio_options(dialog_field, "url", value, selected_value)).to eq(
            :type     => "radio",
            :class    => "100",
            :value    => "bogus",
            :name     => "field_name",
            :checked  => nil,
            :disabled => true,
            :title    => "This element is disabled because it is read only"
          )
        end
      end
    end

    context "when the dialog field is not read only" do
      let(:read_only) { false }
      let(:selected_value) { "some_value" }

      context "when the current value is equal to the default value" do
        let(:value) { "some_value" }

        it "returns the tag options with a disabled true and checked" do
          expect(helper.radio_options(dialog_field, "url", value, selected_value)).to eq(
            :type    => "radio",
            :class   => "100",
            :value   => "some_value",
            :name    => "field_name",
            :checked => '',
          )
        end
      end

      context "when the current value is not equal to the default value" do
        let(:value) { "bogus" }

        it "returns the tag options with a disabled true and checked" do
          expect(helper.radio_options(dialog_field, "url", value, selected_value)).to eq(
            :type    => "radio",
            :class   => "100",
            :value   => "bogus",
            :name    => "field_name",
            :checked => nil,
          )
        end
      end
    end
  end

  describe "#build_auto_refreshable_field_indicies" do
    let(:workflow) { instance_double("ResourceActionWorkflow", :dialog => dialog) }
    let(:dialog) { instance_double("Dialog", :dialog_tabs => [dialog_tab_1, dialog_tab_2]) }
    let(:dialog_tab_1) { instance_double("DialogTab", :dialog_groups => [dialog_group_1, dialog_group_2]) }
    let(:dialog_tab_2) { instance_double("DialogTab", :dialog_groups => [dialog_group_2]) }
    let(:dialog_group_1) do
      instance_double("DialogGroup", :dialog_fields => [dialog_field_1, dialog_field_1, dialog_field_2])
    end
    let(:dialog_group_2) do
      instance_double("DialogGroup", :dialog_fields => [dialog_field_3, dialog_field_2, dialog_field_1])
    end
    let(:dialog_field_1) { instance_double("DialogField", :auto_refresh => nil, :trigger_auto_refresh => false) }
    let(:dialog_field_2) { instance_double("DialogField", :auto_refresh => true, :trigger_auto_refresh => false) }
    let(:dialog_field_3) { instance_double("DialogField", :auto_refresh => false, :trigger_auto_refresh => true) }

    it "builds a list of auto refreshable fields and trigger fields with their indicies" do
      expect(helper.build_auto_refreshable_field_indicies(workflow)).to eq([
        {:tab_index => 0, :group_index => 0, :field_index => 2, :auto_refresh => true},
        {:tab_index => 0, :group_index => 1, :field_index => 0, :auto_refresh => false},
        {:tab_index => 0, :group_index => 1, :field_index => 1, :auto_refresh => true},
        {:tab_index => 1, :group_index => 0, :field_index => 0, :auto_refresh => false},
        {:tab_index => 1, :group_index => 0, :field_index => 1, :auto_refresh => true}
      ])
    end
  end

  describe "#auto_refresh_listening_options" do
    let(:options) { {:trigger => false} }

    it "overrides the trigger attribute" do
      expect(helper.auto_refresh_listening_options(options, true)).to eq(:trigger => true)
    end
  end

  describe "#default_value_form_options" do
    let(:subject) { helper.default_value_form_options(field_type, field_values, field_default_value) }

    context "when the field values are empty" do
      let(:field_values) { [] }

      context "when the field type is a DialogFieldDropDownList" do
        let(:field_type) { "DialogFieldDropDownList" }

        context "when the field default value is set" do
          let(:field_default_value) { "some default" }

          it "adds the ability to select no default value" do
            expect(subject).to eq("<option value=\"\">&lt;None&gt;</option>")
          end
        end

        context "when the field default value is not set" do
          let(:field_default_value) { nil }

          it "adds the ability to select no default value" do
            expect(subject).to eq("<option value=\"\">&lt;None&gt;</option>")
          end
        end
      end

      context "when the field type is a DialogFieldRadioButton" do
        let(:field_type) { "DialogFieldRadioButton" }

        context "when the field default value is set" do
          let(:field_default_value) { "some default" }

          it "adds the ability to select no default value" do
            expect(subject).to eq("<option value=\"\">&lt;None&gt;</option>")
          end
        end

        context "when the field default value is not set" do
          let(:field_default_value) { nil }

          it "adds the ability to select no default value" do
            expect(subject).to eq("<option value=\"\">&lt;None&gt;</option>")
          end
        end
      end
    end

    context "when the field values are not empty" do
      let(:field_values) { [%w(123 456)] }

      context "when the field type is a DialogFieldDropDownList" do
        let(:field_type) { "DialogFieldDropDownList" }

        context "when the field default value is set" do
          let(:field_default_value) { "123" }

          it "selects the default value and does not add any" do
            expect(subject).to eq("<option selected=\"selected\" value=\"123\">456</option>")
          end
        end

        context "when the field default value is not set" do
          let(:field_default_value) { nil }

          it "does not explicitly select anything" do
            expect(subject).to eq("<option value=\"123\">456</option>")
          end
        end
      end

      context "when the field type is a DialogFieldRadioButton" do
        let(:field_type) { "DialogFieldRadioButton" }

        context "when the field default value is set" do
          let(:field_default_value) { "123" }

          it "adds the ability to select no default value but selects the default" do
            expected_html = <<-HTML
<option value=\"\">&lt;None&gt;</option>
<option selected=\"selected\" value=\"123\">456</option>
            HTML
            expect(subject).to eq(expected_html.chomp)
          end
        end

        context "when the field default value is not set" do
          let(:field_default_value) { nil }

          it "adds the ability to select no default value" do
            expected_html = <<-HTML
<option value=\"\">&lt;None&gt;</option>
<option value=\"123\">456</option>
            HTML
            expect(subject).to eq(expected_html.chomp)
          end
        end
      end
    end
  end
end
