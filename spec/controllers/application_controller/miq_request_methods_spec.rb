require "spec_helper"
require "support/controller_spec_helper"

describe MiqRequestController do
  describe "#dialog_partial_for_workflow" do
    before do
      @wf = FactoryGirl.create(:miq_provision_virt_workflow)
    end

    it "calculates partial using wf from @edit hash" do
      controller.instance_variable_set(:@edit, :wf => @wf)
      partial = controller.send(:dialog_partial_for_workflow)
      expect(partial).to eq('shared/views/prov_dialog')
    end

    it "calculates partial using wf from @options hash" do
      controller.instance_variable_set(:@options, :wf => @wf)
      partial = controller.send(:dialog_partial_for_workflow)
      expect(partial).to eq('shared/views/prov_dialog')
    end

    it "calculates partial using wf from @options hash when user is on approve/deny form screen" do
      controller.instance_variable_set(:@edit, :stamp_typ => 'a')
      controller.instance_variable_set(:@options, :wf => @wf)
      partial = controller.send(:dialog_partial_for_workflow)
      expect(partial).to eq('shared/views/prov_dialog')
    end

    it "calculates partial using wf from @edit hash when both @edit & @options are present" do
      controller.instance_variable_set(:@edit, :wf => FactoryGirl.create(:miq_provision_configured_system_foreman_workflow))
      controller.instance_variable_set(:@options, :wf => @wf)
      partial = controller.send(:dialog_partial_for_workflow)
      expect(partial).to eq('prov_configured_system_foreman_dialog')
    end
  end
end
