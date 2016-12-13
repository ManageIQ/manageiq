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
    before do
      val_array = [["cat", "Cat"], ["dog", "Dog"]]
      @val_array_reversed = val_array.collect(&:reverse)
      @field = DialogFieldDropDownList.new(:values => val_array)
    end

    it "not required" do
      @field.required = false
      expect(helper.dialog_dropdown_select_values(@field, nil)).to eq([["<None>", nil]] + @val_array_reversed)
    end

    it "required, nil selected" do
      @field.required = true
      expect(helper.dialog_dropdown_select_values(@field, nil)).to eq([["<Choose>", nil]] + @val_array_reversed)
    end

    it "required, non-nil selected" do
      @field.required = true
      expect(helper.dialog_dropdown_select_values(@field, "cat")).to eq(@val_array_reversed)
    end
  end

  describe "#textbox_tag_options" do
    context "when the field is read_only" do
      let(:read_only) { true }

      it "returns the tag options with a disabled true" do
        expect(helper.textbox_tag_options(dialog_field, "url")).to eq(
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
          expect(helper.textbox_tag_options(dialog_field, "url")).to eq(
            :maxlength         => 50,
            :class             => "dynamic-text-box-100 form-control",
            "data-miq_observe" => '{"url":"url"}'
          )
        end
      end

      context "when the dialog field triggers auto refresh" do
        let(:trigger_auto_refresh) { true }

        it "returns the tag options with a data-miq-observe" do
          expect(helper.textbox_tag_options(dialog_field, "url")).to eq(
            :maxlength         => 50,
            :class             => "dynamic-text-box-100 form-control",
            "data-miq_observe" => {
              :url          => "url",
              :auto_refresh => true,
              :field_id     => "100",
              :trigger      => "true"
            }.to_json
          )
        end
      end
    end
  end

  describe "#textarea_tag_options" do
    context "when the field is read_only" do
      let(:read_only) { true }

      it "returns the tag options with a disabled true" do
        expect(helper.textarea_tag_options(dialog_field, "url")).to eq(
          :class     => "dynamic-text-area-100 form-control",
          :size      => "50x6",
          :disabled  => true,
          :title     => "This element is disabled because it is read only"
        )
      end
    end

    context "when the dialog field is not read only" do
      let(:read_only) { false }

      context "when the dialog field triggers auto refresh" do
        let(:trigger_auto_refresh) { true }

        it "returns the tag options with a data-miq-observe" do
          expect(helper.textarea_tag_options(dialog_field, "url")).to eq(
            :class             => "dynamic-text-area-100 form-control",
            :size              => "50x6",
            "data-miq_observe" => {
              :url          => "url",
              :auto_refresh => true,
              :field_id     => "100",
              :trigger      => "true"
            }.to_json
          )
        end
      end

      context "when the dialog field does not trigger auto refresh" do
        let(:trigger_auto_refresh) { false }

        it "returns the tag options with a data-miq-observe" do
          expect(helper.textarea_tag_options(dialog_field, "url")).to eq(
            :class             => "dynamic-text-area-100 form-control",
            :size              => "50x6",
            "data-miq_observe" => '{"url":"url"}'
          )
        end
      end
    end
  end

  describe "#checkbox_tag_options" do
    context "when the field is read_only" do
      let(:read_only) { true }

      it "returns the tag options with a disabled true" do
        expect(helper.checkbox_tag_options(dialog_field, "url")).to eq(
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
          expect(helper.checkbox_tag_options(dialog_field, "url")).to eq(
            :class                      => "dynamic-checkbox-100",
            "data-miq_sparkle_on"       => true,
            "data-miq_sparkle_off"      => true,
            "data-miq_observe_checkbox" => '{"url":"url","auto_refresh":true,"field_id":"100","trigger":"true"}'
          )
        end
      end

      context "when the dialog field does not trigger auto refresh" do
        let(:trigger_auto_refresh) { false }

        it "returns the tag options with a few data-miq attributes" do
          expect(helper.checkbox_tag_options(dialog_field, "url")).to eq(
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
    context "when the field is read_only" do
      let(:read_only) { true }

      it "returns the tag options with a disabled true" do
        expect(helper.date_tag_options(dialog_field, "url")).to eq(
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
          expect(helper.date_tag_options(dialog_field, "url")).to eq(
            :class                  => "css1 dynamic-date-100",
            :readonly               => "true",
            "data-miq_observe_date" => '{"url":"url","auto_refresh":true,"field_id":"100","trigger":"true"}'
          )
        end
      end

      context "when the dialog field does not trigger auto refresh" do
        let(:trigger_auto_refresh) { false }

        it "returns the tag options with a few data-miq attributes" do
          expect(helper.date_tag_options(dialog_field, "url")).to eq(
            :class                  => "css1 dynamic-date-100",
            :readonly               => "true",
            "data-miq_observe_date" => '{"url":"url"}'
          )
        end
      end
    end
  end

  describe "#time_tag_options" do
    context "when the field is read_only" do
      let(:read_only) { true }

      it "returns the tag options with a disabled true" do
        expect(helper.time_tag_options(dialog_field, "url", "hour_or_min")).to eq(
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
          expect(helper.time_tag_options(dialog_field, "url", "hour_or_min")).to eq(
            :class             => "dynamic-date-hour_or_min-100",
            "data-miq_observe" => '{"url":"url","auto_refresh":true,"field_id":"100","trigger":"true"}'
          )
        end
      end

      context "when the dialog field does not trigger auto refresh" do
        let(:trigger_auto_refresh) { false }

        it "returns the tag options with a few data-miq attributes" do
          expect(helper.time_tag_options(dialog_field, "url", "hour_or_min")).to eq(
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
            :id       => "100",
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
            :id       => "100",
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
      let(:onclick_string) do
        "$.ajax(" \
          "{beforeSend:function(request){miqSparkle(true);}, " \
          "complete:function(request){miqSparkle(false);}, " \
          "data:miqSerializeForm('dynamic-radio-100'), " \
          "dataType:'script', " \
          "type:'post', " \
          "url:'url'}" \
        ")"
      end

      context "when the current value is equal to the default value" do
        let(:value) { "some_value" }

        context "when the dialog field triggers auto refresh" do
          let(:trigger_auto_refresh) { true }

          it "returns the tag options with a disabled true and checked" do
            expect(helper.radio_options(dialog_field, "url", value, selected_value)).to eq(
              :type    => "radio",
              :id      => "100",
              :value   => "some_value",
              :name    => "field_name",
              :checked => '',
              :onclick => "dialogFieldRefresh.triggerAutoRefresh('100', 'true');" + onclick_string
            )
          end
        end

        context "when the dialog field does not trigger auto refresh" do
          let(:trigger_auto_refresh) { false }

          it "returns the tag options with a disabled true and checked" do
            expect(helper.radio_options(dialog_field, "url", value, selected_value)).to eq(
              :type    => "radio",
              :id      => "100",
              :value   => "some_value",
              :name    => "field_name",
              :checked => '',
              :onclick => onclick_string
            )
          end
        end
      end

      context "when the current value is not equal to the default value" do
        let(:value) { "bogus" }

        context "when the dialog field triggers auto refresh" do
          let(:trigger_auto_refresh) { true }

          it "returns the tag options with a disabled true and checked" do
            expect(helper.radio_options(dialog_field, "url", value, selected_value)).to eq(
              :type    => "radio",
              :id      => "100",
              :value   => "bogus",
              :name    => "field_name",
              :checked => nil,
              :onclick => "dialogFieldRefresh.triggerAutoRefresh('100', 'true');" + onclick_string
            )
          end
        end

        context "when the dialog field does not trigger auto refresh" do
          let(:trigger_auto_refresh) { false }

          it "returns the tag options with a disabled true and checked" do
            expect(helper.radio_options(dialog_field, "url", value, selected_value)).to eq(
              :type    => "radio",
              :id      => "100",
              :value   => "bogus",
              :name    => "field_name",
              :checked => nil,
              :onclick => onclick_string
            )
          end
        end
      end
    end
  end
end
