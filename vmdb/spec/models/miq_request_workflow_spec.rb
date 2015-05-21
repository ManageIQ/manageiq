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
        expect(wf_with_validation).to receive(:respond_to?).with(:some_validation_method).and_return(true)
        expect(wf_with_validation).to receive(:some_validation_method).once
        expect(wf_with_validation.validate({})).to be_true
      end

      it "returns false when validation fails" do
        expect(wf_with_validation).to receive(:respond_to?).with(:some_validation_method).and_return(true)
        expect(wf_with_validation).to receive(:some_validation_method).and_return("Some Error")
        expect(wf_with_validation.validate({})).to be_false
      end
    end

    context 'required_method is only run on visible fields' do
      let(:wf_with_required_method) { FactoryGirl.build(:miq_provision_workflow, :factory_dialog => :miq_dialog_provision_with_required_method) }

      it "field hidden" do
        wf_with_required_method.instance_variable_get(:@dialogs).store_path(:dialogs, :hardware, :fields, :memory_reserve, :display, :hide)

        expect(wf_with_required_method).to_not receive(:some_required_method)
        expect(wf_with_required_method.validate({})).to be_true
      end

      it "field visible" do
        expect(wf_with_required_method).to receive(:some_required_method).and_return("Some Error")
        expect(wf_with_required_method.validate({})).to be_false
      end
    end
  end
end
