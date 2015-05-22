require "spec_helper"

describe MiqRequestWorkflow do
  context "#validate" do
    context "validation_method" do
      let(:wf_without_validation) { FactoryGirl.build(:miq_provision_workflow) }
      let(:wf_with_validation)    { FactoryGirl.build(:miq_provision_workflow, :factory_dialog => :miq_dialog_provision_with_validation_method) }

      it "skips validation if no validation_method is defined" do
        expect(wf_without_validation.get_all_dialogs[:customize][:fields][:root_password][:validation_method]).to eq(nil)
        expect(wf_without_validation.validate({})).to be_true
      end

      it "calls the validation_method if defined" do
        wf_with_validation.should_receive(:respond_to?).with(:some_validation_method).and_return(true)
        wf_with_validation.should_receive(:some_validation_method).once
        expect(wf_with_validation.validate({})).to be_true
      end

      it "returns false when validation fails" do
        wf_with_validation.should_receive(:respond_to?).with(:some_validation_method).and_return(true)
        wf_with_validation.should_receive(:some_validation_method).and_return("Some Error")
        expect(wf_with_validation.validate({})).to be_false
      end
    end
  end
end
