describe CatalogController do
  describe "#dialog_field_changed" do
    include_context "valid session"

    let(:dialog) { double("Dialog") }
    let(:wf) { double(:dialog => dialog) }
    let(:dialog_field) do
      double("DialogFieldTextBox", :name => "test", :value => nil, :type => "TextBox")
    end
    let(:params) { {:test => "new value", :id => 123} }
    let(:session) { {:edit => {:rec_id => 123, :wf => wf, :key => "dialog_edit__123"}} }

    before do
      allow(Dialog).to receive(:find_by_id).with(123).and_return(dialog)
      allow(dialog).to receive(:field)
      allow(dialog).to receive(:field).with("test").and_return(dialog_field)
      allow(dialog).to receive(:field_name_exist?).and_return(false)
      allow(dialog).to receive(:field_name_exist?).with("test").and_return(true)
      allow(dialog).to receive(:dialog_tabs)
        .and_return([double(:dialog_groups => [double(:dialog_fields => [dialog_field])])])
      allow(wf).to receive(:dialog_field).with("test").and_return(double(:data_type => "string"))
      allow(wf).to receive(:set_value)
    end

    it "includes disabling the sparkle in the response" do
      post :dialog_field_changed, :params => params, :session => session, :xhr => true
      expect(response.body).to include("miqSparkle(false);")
    end

    it "stores the incoming value in the edit variable" do
      expect(wf).to receive(:set_value).with("test", "new value")
      post :dialog_field_changed, :params => params, :session => session, :xhr => true
    end
  end

  describe "#dynamic_text_box_refresh" do
    include_context "valid session"

    let(:dialog) { double("Dialog") }
    let(:wf) { double(:dialog => dialog) }
    let(:dialog_field) { double("DialogFieldTextBox", :refresh_json_value => "lol") }

    let(:params)  { {:name => "name"} }
    let(:session) { {:edit => {:wf => wf}} }

    before do
      allow(dialog).to receive(:field).with("name").and_return(dialog_field)
    end

    it "returns the correct json response" do
      post :dynamic_checkbox_refresh, :params => params, :session => session, :xhr => true
      expect(response.body).to eq({:values => "lol"}.to_json)
    end
  end

  describe "#dynamic_checkbox_refresh" do
    include_context "valid session"

    let(:dialog) { double("Dialog") }
    let(:wf) { double(:dialog => dialog) }
    let(:dialog_field) { double("DialogFieldCheckBox", :refresh_json_value => "true") }

    let(:params)  { {:name => "name"} }
    let(:session) { {:edit => {:wf => wf}} }

    before do
      allow(dialog).to receive(:field).with("name").and_return(dialog_field)
    end

    it "returns the correct json response" do
      post :dynamic_checkbox_refresh, :params => params, :session => session, :xhr => true
      expect(response.body).to eq({:values => "true"}.to_json)
    end
  end

  describe "#dynamic_date_refresh" do
    include_context "valid session"

    let(:dialog) { double("Dialog") }
    let(:wf) { double(:dialog => dialog) }
    let(:dialog_field) { double("DialogFieldDateControl", :refresh_json_value => "01/02/2015") }

    let(:params) { {:name => "name"} }
    let(:session) { {:edit => {:wf => wf}} }

    before do
      allow(dialog).to receive(:field).with("name").and_return(dialog_field)
    end

    it "returns the correct json response" do
      post :dynamic_date_refresh, :params => params, :session => session, :xhr => true
      expect(response.body).to eq({:values => "01/02/2015"}.to_json)
    end
  end

  describe "#dialog_get_form_vars" do
    include_context "valid session"

    let(:dialog) { double("Dialog") }
    let(:wf) { double(:dialog => dialog) }
    let(:dialog_field) { DialogFieldDateTimeControl.new }

    let(:session) { {:edit => {:wf => wf}} }

    before do
      allow(dialog).to receive(:field).with("name").and_return(dialog_field)
      allow(dialog).to receive(:field_name_exist?).with("name").and_return(true)
      allow(dialog).to receive(:dialog_fields) { [Struct.new(:name, :type).new("name", "DialogFieldDateTimeControl")] }
      allow(wf).to receive(:value).with("name") { dialog_field.value }
      allow(wf).to receive(:set_value) { |_, val| dialog_field.instance_variable_set(:@value, val) }
      allow(Dialog).to receive(:find_by_id).and_return(dialog)

      dialog_field.instance_variable_set(:@value, "04/05/2015 14:52")
      controller.instance_variable_set(:@edit, {:rec_id => nil, :wf => wf})
    end

    it "keeps hours and minutes when setting date" do
      allow(controller).to receive(:params).and_return('miq_date__name' => "11/13/2015")
      controller.send(:dialog_get_form_vars)
      expect(dialog_field.value).to eq('11/13/2015 14:52')
    end

    it "keeps date and minutes when setting hours" do
      allow(controller).to receive(:params).and_return('start_hour' => "4")
      controller.send(:dialog_get_form_vars)
      expect(dialog_field.value).to eq('04/05/2015 04:52')
    end

    it "keeps date and hourse when setting minutes" do
      allow(controller).to receive(:params).and_return('start_min' => "6")
      controller.send(:dialog_get_form_vars)
      expect(dialog_field.value).to eq('04/05/2015 14:06')
    end
  end

  describe "#dialog_form_button_pressed" do
    let(:dialog) { double("Dialog") }
    let(:workflow) { FactoryGirl.build(:miq_provision_workflow) }
    let(:wf) { double(:dialog => dialog) }

    before do
      edit = {:rec_id => 1, :wf => wf, :key => 'dialog_edit__foo', :explorer => 'true'}
      controller.instance_variable_set(:@edit, edit)
      controller.instance_variable_set(:@sb, {})
      session[:edit] = edit
    end

    it "redirects to requests show list after the dialog is submitted if a request is created" do
      controller.instance_variable_set(:@_params, :button => 'submit', :id => 'foo')
      allow(controller).to receive(:role_allows?).and_return(true)
      allow(wf).to receive(:submit_request).and_return(:request => workflow.make_request(nil, {}))
      page = double('page')
      allow(page).to receive(:<<).with(any_args)
      expect(page).to receive(:redirect_to).with(:controller => "miq_request",
                                             :action     => "show_list",
                                             :flash_msg  => "Order Request was Submitted")
      expect(controller).to receive(:render).with(:update).and_yield(page)
      controller.send(:dialog_form_button_pressed)
    end

    it "stay on the current model page after the dialog is submitted if a request is not created" do
      controller.instance_variable_set(:@_params, :button => 'submit', :id => 'foo')
      st = FactoryGirl.create(:service_template)
      controller.x_node = "xx-st st-#{st.id}"
      allow(controller).to receive(:role_allows?).and_return(true)
      allow(controller).to receive(:get_node_info)
      allow(controller).to receive(:render)
      allow(wf).to receive(:submit_request).and_return({})
      expect(controller).to receive(:replace_right_cell)
      controller.send(:dialog_form_button_pressed)
    end
  end
end
