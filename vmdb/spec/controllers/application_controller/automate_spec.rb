require "spec_helper"
include UiConstants

describe MiqAeCustomizationController do
  describe ApplicationController::Automate do
    context "#resolve" do
      before(:each) do
        set_user_privileges
      end
      it "Simulate button from custom buttons should redirect to resolve" do
        custom_button = FactoryGirl.create(:custom_button, :applies_to_class => "Host")
        target_classes = {}
        CustomButton.button_classes.each{|db| target_classes[db] = ui_lookup(:model=>db)}
        resolve = {
            :new => {:target_class => custom_button.applies_to_class},
            :target_classes => target_classes
        }
        session[:resolve] = resolve
        controller.instance_variable_set(:@resolve, resolve)
        post :resolve, :button => "simulate", :id => custom_button.id
        response.body.should include("miq_ae_tools/resolve?escape=false&simulate=simulate")
      end
    end
  end
end
