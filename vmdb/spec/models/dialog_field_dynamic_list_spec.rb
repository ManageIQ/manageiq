require "spec_helper"

describe DialogFieldDynamicList do
  context "dialog_field_dynamic_list" do
    before(:each) do
      @df = FactoryGirl.create(:dialog_field_dynamic_list, :label => 'dynamic_list', :name => 'dynamic_list')
    end

    it "#resource_action" do
      @df.resource_action.should_not be_nil
    end

    it "#default_resource_action" do
      @df.resource_action = nil
      @df.default_resource_action
      @df.resource_action.should_not be_nil
    end

    it "refresh_button_pressed" do
      @df.should_receive(:values).once
      @df.refresh_button_pressed
      @df.default_value.should be_nil
    end

    it "refresh_button_pressed" do
      @df.should_receive(:values).once
      @df.refresh_button_pressed
      @df.default_value.should be_nil
    end

    context "#raw_values" do
      it "raw_values first call" do
        @df.should_receive(:values_from_automate).once
        @df.raw_values
      end

      it "raw_values with cached values" do
        @df.should_receive(:values_from_automate).once.and_return([])
        @df.raw_values
        @df.raw_values
      end
    end

    context "#load_values_on_init?" do
      it "default" do
        @df.load_values_on_init?.should be_false
      end

      it "with load init true" do
        @df.options[:load_values_on_init] = true
        @df.load_values_on_init?.should be_true
      end

      it "with load init false and show button false" do
        @df.options[:load_values_on_init] = false
        @df.options[:show_refresh_button] = false
        @df.load_values_on_init?.should be_true
      end

      it "with load init false and show button true" do
        @df.options[:load_values_on_init] = false
        @df.options[:show_refresh_button] = true
        @df.load_values_on_init?.should be_false
      end
    end

    context "#normalize_automate_values" do
      it "with nil input" do
        @df.normalize_automate_values(nil).should == [[nil, "<None>"]]
      end

      it "with empty array input" do
        @df.normalize_automate_values([]).should == [[nil, "<None>"]]
      end

      it "with empty hash input" do
        @df.normalize_automate_values({}).should == [[nil, "<None>"]]
      end

      it "with array input" do
        args = [[1,"one"], [2,"two"]]
        @df.normalize_automate_values(args).should == [[1, "one"], [2, "two"]]
      end

      it "with hash input" do
        args = {1 => "one", 2 => "two"}
        @df.normalize_automate_values(args).should == [[1, "one"], [2, "two"]]
      end
    end

    context "with values returned from automate" do
      before(:each) do
        @ws = mock
        @ws.stub(:root).and_return(@root = mock)
        @root.stub(:attributes).and_return(@ws_attributes = {})
      end

      context "#initialize_with_values(dialog_values)" do
        it "load_values_on_init is false" do
          @df.stub(:load_values_on_init?).and_return(false)
          @df.initialize_with_values({}).should == [[nil, "<None>"]]
        end

        it "load_values_on_init is true with default value" do
          @df.stub(:load_values_on_init?).and_return(true)
          @ws_attributes.merge!({"values" => [[1, "one"]], "default_value" => 1})
          @df.resource_action.stub(:deliver_to_automate_from_dialog_field).and_return(@ws)
          @df.initialize_with_values({}).should == 1
        end
      end

      context "#values_from_automate" do
        it "raise error" do
          @df.resource_action.stub(:deliver_to_automate_from_dialog_field).and_raise
          @df.values_from_automate.should == [[nil, "<Script error>"]]
        end

        it "automate returning array" do
          @ws_attributes.merge!({"values" => [[1, "one"]]})
          @df.resource_action.stub(:deliver_to_automate_from_dialog_field).and_return(@ws)
          @df.values_from_automate.should == [[1, "one"]]
        end
      end
    end

    context "#process_automate_values" do
      context "sort_by" do
        it "sort_by not set" do
          @df.sort_by.should == :description
        end

        it "sort_by none" do
          @df.process_automate_values({"sort_by" => "none"})
          @df.sort_by.should == :none
        end

        it "sort_by invalid" do
          expect { @df.process_automate_values({"sort_by" => "key"}) }.to raise_error
        end
      end

      context "sort_order" do
        it "sort_order not set" do
          @df.sort_order.should == :ascending
        end

        it "sort_order descending" do
          @df.process_automate_values({"sort_order" => "descending"})
          @df.sort_order.should == :descending
        end

        it "sort_order invalid" do
          expect { @df.process_automate_values({"sort_order" => "none"}) }.to raise_error
        end
      end

      context "required" do
        it "required not set" do
          @df.required.should == false
        end

        it "required true" do
          @df.process_automate_values({"required" => "true"})
          @df.required.should == true
        end

        it "required false" do
          @df.required = true
          @df.process_automate_values({"required" => "false"})
          @df.required.should == false
        end
      end

      context "default_value" do
        it "default_value not set" do
          @df.process_automate_values({})
          @df.default_value.should be_nil
        end

        it "default_value with no matching values " do
          @df.process_automate_values({"default_value" => 1})
          @df.default_value.should == 1
        end
      end

    end
  end
end
