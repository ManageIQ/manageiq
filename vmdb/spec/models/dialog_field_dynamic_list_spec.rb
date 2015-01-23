require "spec_helper"

describe DialogFieldDynamicList do
  let(:dialog_field) do
    FactoryGirl.build(:dialog_field_dynamic_list, :label => 'dynamic_list', :name => 'dynamic_list')
  end

  it "#resource_action" do
    dialog_field.resource_action.should_not be_nil
  end

  it "#default_resource_action" do
    dialog_field.resource_action = nil
    dialog_field.default_resource_action
    dialog_field.resource_action.should_not be_nil
  end

  describe "#raw_values" do
    it "raw_values first call" do
      dialog_field.should_receive(:values_from_automate).once
      dialog_field.raw_values
    end

    it "raw_values with cached values" do
      dialog_field.should_receive(:values_from_automate).once.and_return([])
      dialog_field.raw_values
      dialog_field.raw_values
    end
  end

  describe "#load_values_on_init?" do
    it "default" do
      dialog_field.load_values_on_init?.should be_false
    end

    it "with load init true" do
      dialog_field.load_values_on_init = true
      dialog_field.load_values_on_init?.should be_true
    end

    it "with load init false and show button false" do
      dialog_field.load_values_on_init = false
      dialog_field.show_refresh_button = false
      dialog_field.load_values_on_init?.should be_true
    end

    it "with load init false and show button true" do
      dialog_field.load_values_on_init = false
      dialog_field.show_refresh_button = true
      dialog_field.load_values_on_init?.should be_false
    end
  end

  context "with values returned from automate" do
    before(:each) do
      @ws = double
      @ws.stub(:root).and_return(@root = double)
      @root.stub(:attributes).and_return(@ws_attributes = {})
    end

    context "#initialize_with_values(dialog_values)" do
      it "load_values_on_init is false" do
        dialog_field.stub(:load_values_on_init?).and_return(false)
        dialog_field.initialize_with_values({}).should == [[nil, "<None>"]]
      end

      it "load_values_on_init is true with default value" do
        dialog_field.stub(:load_values_on_init?).and_return(true)
        @ws_attributes.merge!("values" => [[1, "one"]], "default_value" => 1)
        dialog_field.resource_action.stub(:deliver_to_automate_from_dialog_field).and_return(@ws)
        dialog_field.initialize_with_values({}).should == 1
      end
    end

    context "#values_from_automate" do
      it "raise error" do
        dialog_field.resource_action.stub(:deliver_to_automate_from_dialog_field).and_raise
        dialog_field.values_from_automate.should == [[nil, "<Script error>"]]
      end

      it "automate returning array" do
        @ws_attributes.merge!("values" => [[1, "one"]])
        dialog_field.resource_action.stub(:deliver_to_automate_from_dialog_field).and_return(@ws)
        dialog_field.values_from_automate.should == [[1, "one"]]
      end
    end
  end

  describe "#refresh_button_pressed" do
    before do
      DynamicDialogFieldValueProcessor.stub(:values_from_automate).with(dialog_field).and_return(
        [["processor", 123]]
      )
    end

    it "returns the values from the value processor" do
      expect(dialog_field.refresh_button_pressed).to eq([["processor", 123]])
    end
  end

  describe "#initialize_with_values" do
    context "when show refresh button is true" do
      before do
        dialog_field.show_refresh_button = true
      end

      context "when load values on init is true" do
        before do
          dialog_field.load_values_on_init = true
          DynamicDialogFieldValueProcessor.stub(:values_from_automate).with(dialog_field).and_return(
            [["processor", 123]]
          )

          dialog_field.initialize_with_values("lolvalues")
        end

        it "gets values from automate" do
          expect(dialog_field.instance_variable_get(:@raw_values)).to eq([["processor", 123]])
        end
      end

      context "when load values on init is false" do
        before do
          dialog_field.load_values_on_init = false
          dialog_field.initialize_with_values("lolvalues")
        end

        it "sets raw_values to initial values" do
          expect(dialog_field.instance_variable_get(:@raw_values)).to eq([[nil, "<None>"]])
        end
      end
    end

    context "when show refresh button is false" do
      before do
        dialog_field.show_refresh_button = false
        DynamicDialogFieldValueProcessor.stub(:values_from_automate).with(dialog_field).and_return(
          [["processor", 123]]
        )

        dialog_field.initialize_with_values("lolvalues")
      end

      it "gets values from automate" do
        expect(dialog_field.instance_variable_get(:@raw_values)).to eq([["processor", 123]])
      end
    end
  end
end
