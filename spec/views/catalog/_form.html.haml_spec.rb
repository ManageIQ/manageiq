describe "catalog/_form.html.haml" do
  before do
    set_controller_for_view("catalog")
    set_controller_for_view_to_be_nonrestful
    @edit = {:new => {:available_catalogs => [], :available_dialogs => {}}}
    @sb = {:st_form_active_tab => "Basic"}
  end

  it "Renders form when adding catalog bundle and st_prov_type is not set" do
    render
    expect(response).to render_template(:partial => "catalog/_form_basic_info")
  end
end
