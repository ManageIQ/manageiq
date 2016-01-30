include UiConstants

describe PxeController do
  context "#template_create_update" do
    it "correct method is being called when reset button is pressed" do
      customization_template = FactoryGirl.create(:customization_template)
      controller.instance_variable_set(:@sb,                                           :trees       => {
                                         :customization_templates_tree => {
                                           :active_node => "xx-xx-#{customization_template.id}"
                                         }
                                       },
                                                                                       :active_tree => :customization_templates_tree
                                      )
      edit = {
        :new => {
          :name        => "New Name",
          :description => "New Description",
          :script      => "Some script"
        },
        :key => "ct_edit__#{customization_template.id}"
      }
      controller.instance_variable_set(:@edit, edit)
      session[:edit] = edit
      controller.instance_variable_set(:@_params,                                           :id     => customization_template.id,
                                                                                            :button => "reset"
                                      )
      expect(controller).to receive(:customization_template_edit)
      controller.template_create_update
      expect(assigns(:flash_array).first[:message]).to include("reset")
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end
  end
end
