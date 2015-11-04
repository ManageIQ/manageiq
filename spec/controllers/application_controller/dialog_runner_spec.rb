require "spec_helper"
require "support/controller_spec_helper"

describe CatalogController do
  describe "#dynamic_text_box_refresh" do
    include_context "valid session"

    let(:dialog) { active_record_instance_double("Dialog") }
    let(:wf) { double(:dialog => dialog) }
    let(:dialog_field) { active_record_instance_double("DialogFieldTextBox", :refresh_json_value => "lol") }

    let(:params)  { {:name => "name"} }
    let(:session) { {:edit => {:wf => wf}} }

    before do
      dialog.stub(:field).with("name").and_return(dialog_field)
    end

    it "returns the correct json response" do
      xhr :post, :dynamic_checkbox_refresh, params, session
      expect(response.body).to eq({:values => "lol"}.to_json)
    end
  end

  describe "#dynamic_checkbox_refresh" do
    include_context "valid session"

    let(:dialog) { active_record_instance_double("Dialog") }
    let(:wf) { double(:dialog => dialog) }
    let(:dialog_field) { active_record_instance_double("DialogFieldCheckBox", :refresh_json_value => "true") }

    let(:params)  { {:name => "name"} }
    let(:session) { {:edit => {:wf => wf}} }

    before do
      dialog.stub(:field).with("name").and_return(dialog_field)
    end

    it "returns the correct json response" do
      xhr :post, :dynamic_checkbox_refresh, params, session
      expect(response.body).to eq({:values => "true"}.to_json)
    end
  end

  describe "#dynamic_date_refresh" do
    include_context "valid session"

    let(:dialog) { active_record_instance_double("Dialog") }
    let(:wf) { double(:dialog => dialog) }
    let(:dialog_field) { active_record_instance_double("DialogFieldDateControl", :refresh_json_value => "01/02/2015") }

    let(:params) { {:name => "name"} }
    let(:session) { {:edit => {:wf => wf}} }

    before do
      dialog.stub(:field).with("name").and_return(dialog_field)
    end

    it "returns the correct json response" do
      xhr :post, :dynamic_date_refresh, params, session
      expect(response.body).to eq({:values => "01/02/2015"}.to_json)
    end
  end

  describe "#dialog_get_form_vars" do
    include_context "valid session"

    let(:dialog) { active_record_instance_double("Dialog") }
    let(:wf) { double(:dialog => dialog) }
    let(:dialog_field) { DialogFieldDateTimeControl.new }

    let(:session) { {:edit => {:wf => wf}} }

    before do
      dialog.stub(:field).with("name").and_return(dialog_field)
      dialog.stub(:field_name_exist?).with("name").and_return(true)
      dialog.stub(:dialog_fields) { [Struct.new(:name, :type).new("name", "DialogFieldDateTimeControl")] }
      wf.stub(:value).with("name") { dialog_field.value }
      wf.stub(:set_value) { |_, val| dialog_field.instance_variable_set(:@value, val) }
      Dialog.stub(:find_by_id).and_return(dialog)

      dialog_field.instance_variable_set(:@value, "04/05/2015 14:52")
      controller.instance_variable_set(:@edit, {:rec_id => nil, :wf => wf})
    end

    it "keeps hours and minutes when setting date" do
      controller.stub(:params).and_return({'miq_date__name' => "11/13/2015"})
      controller.send(:dialog_get_form_vars)
      expect(dialog_field.value).to eq('11/13/2015 14:52')
    end

    it "keeps date and minutes when setting hours" do
      controller.stub(:params).and_return({'start_hour' => "4"})
      controller.send(:dialog_get_form_vars)
      expect(dialog_field.value).to eq('04/05/2015 04:52')
    end

    it "keeps date and hourse when setting minutes" do
      controller.stub(:params).and_return({'start_min' => "6"})
      controller.send(:dialog_get_form_vars)
      expect(dialog_field.value).to eq('04/05/2015 14:06')
    end
  end
end
