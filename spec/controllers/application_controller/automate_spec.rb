describe MiqAeCustomizationController, "ApplicationController::Automate" do
  context "#resolve" do
    before(:each) do
      set_user_privileges
    end
    it "Simulate button from custom buttons should redirect to resolve" do
      custom_button = FactoryGirl.create(:custom_button, :applies_to_class => "Host")
      target_classes = {}
      CustomButton.button_classes.each { |db| target_classes[db] = ui_lookup(:model => db) }
      resolve = {
        :new            => {:target_class => custom_button.applies_to_class},
        :target_classes => target_classes
      }
      session[:resolve] = resolve
      controller.instance_variable_set(:@resolve, resolve)
      post :resolve, :params => { :button => "simulate", :id => custom_button.id }
      expect(response.body).to include("miq_ae_tools/resolve?escape=false&simulate=simulate")
    end
  end
end

describe MiqAeToolsController, "ApplicationController::Automate" do
  context "#build_results" do
    let(:custom_button) { FactoryGirl.create(:custom_button, :applies_to_class => "Host") }
    let(:workspace) { double("MiqAeEngine::MiqAeWorkspaceRuntime", :root => options) }
    before(:each) do
      set_user_privileges
    end

    def resolve_hash(button)
      target_classes = {}
      CustomButton.button_classes.each { |db| target_classes[db] = ui_lookup(:model => db) }
      {
        :new            => {:target_class => button.applies_to_class},
        :target_classes => target_classes
      }
    end

    context 'submit' do
      let(:options) { {'ae_result' => 'ok'} }
      it 'ok' do
        resolve = resolve_hash(custom_button)
        session[:resolve] = resolve
        sb = {:name => 'test', :vmdb_object => nil, :attrs => {'a' => 1}}
        controller.instance_variable_set(:@resolve, resolve)
        controller.instance_variable_set(:@sb, sb)
        controller.instance_variable_set(:@_params, :button => 'throw')
        allow(MiqAeEngine).to receive(:resolve_automation_object).and_return(workspace)
        allow(workspace).to receive(:to_expanded_xml).and_return("<A/>")
        allow(MiqAeToolsController).to receive(:ws_tree_from_xml).and_return(nil)
        controller.build_results
        expect(resolve[:ae_result]).to eql('ok')
        expect(resolve[:state_attributes]).to be_empty
      end
    end

    context 'state machine' do
      let(:options) { {'ae_result' => 'retry', 'ae_state' => 'state1'} }
      it "retry" do
        state_hash = {'var1' => 1, 'var2' => 2}
        resolve = resolve_hash(custom_button)
        resolve[:state_attributes] = {'ae_state' => 'state3'}
        session[:resolve] = resolve
        sb = {:name => 'test', :vmdb_object => nil, :attrs => {'a' => 1}}
        controller.instance_variable_set(:@resolve, resolve)
        controller.instance_variable_set(:@sb, sb)
        controller.instance_variable_set(:@_params, :button => 'retry')
        allow(MiqAeEngine).to receive(:resolve_automation_object).and_return(workspace)
        allow(workspace).to receive(:to_expanded_xml).and_return("<A/>")
        allow(workspace).to receive(:persist_state_hash).and_return(state_hash)
        allow(workspace).to receive(:current_state_info).and_return({})
        allow(MiqAeToolsController).to receive(:ws_tree_from_xml).and_return(nil)
        controller.build_results
        expect(resolve[:ae_result]).to eql('retry')
        expect(resolve[:state_attributes]['ae_state']).to eql('state1')
      end
    end
  end
end
