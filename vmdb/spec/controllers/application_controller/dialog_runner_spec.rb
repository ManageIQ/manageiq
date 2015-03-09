require "spec_helper"
require "support/controller_spec_helper"

describe CatalogController do
  describe "#dynamic_list_refresh" do
    include_context "valid session"

    let(:dialog)       { Dialog.new }
    let(:values)       { [%w(key_1 description_1), %w(key_2 description_2)] }
    let(:wf)           { double(:dialog => dialog) }

    let(:params)  { {:id => 321} }
    let(:session) { {:edit => {:rec_id => 123, :wf => wf}} }

    before do
      dialog.stub(:field).with("321").and_return(dialog_field)
      wf.stub(:value).with("test").and_return("selected value")
      dialog_field.stub(:values).and_return(values)
    end

    context "when the dialog field is a DialogFieldDynamicList" do
      let(:dialog_field) { DialogFieldDynamicList.new(:name => "test") }

      it "assigns select options with reverse order" do
        post :dynamic_list_refresh, params, session
        expect(assigns(:select_options)).to eq(values.collect(&:reverse))
      end
    end

    context "when the dialog field is not a DialogFieldDynamicList" do
      let(:dialog_field) { DialogField.new(:name => "test") }

      before do
        dialog_field.stub(:refresh_button_pressed)
      end

      it "assigns select options with regular order" do
        post :dynamic_list_refresh, params, session
        expect(assigns(:select_options)).to eq(values)
      end
    end
  end

  describe "#dynamic_text_box_refresh" do
    include_context "valid session"

    let(:dialog) { active_record_instance_double("Dialog") }
    let(:wf) { double(:dialog => dialog) }
    let(:dialog_field) { active_record_instance_double("DialogFieldTextBox", :refresh_json_value=> "lol") }

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
    let(:dialog_field) { active_record_instance_double("DialogFieldCheckBox", :refresh_json_value=> "true") }

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
end
