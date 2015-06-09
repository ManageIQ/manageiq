require "spec_helper"

describe MiqRequestWorkflow do
  context "#validate" do
    let(:dialog)   { workflow.instance_variable_get(:@dialogs) }
    let(:workflow) { FactoryGirl.build(:miq_provision_workflow) }

    context "validation_method" do
      it "skips validation if no validation_method is defined" do
        expect(workflow.get_all_dialogs[:customize][:fields][:root_password][:validation_method]).to eq(nil)
        expect(workflow.validate({})).to be_true
      end

      it "calls the validation_method if defined" do
        dialog.store_path(:dialogs, :customize, :fields, :root_password, :validation_method, :some_validation_method)

        expect(workflow).to receive(:respond_to?).with(:some_validation_method).and_return(true)
        expect(workflow).to receive(:some_validation_method).once
        expect(workflow.validate({})).to be_true
      end

      it "returns false when validation fails" do
        dialog.store_path(:dialogs, :customize, :fields, :root_password, :validation_method, :some_validation_method)

        expect(workflow).to receive(:respond_to?).with(:some_validation_method).and_return(true)
        expect(workflow).to receive(:some_validation_method).and_return("Some Error")
        expect(workflow.validate({})).to be_false
      end
    end

    context 'required_method is only run on visible fields' do
      it "field hidden" do
        dialog.store_path(:dialogs, :customize, :fields, :root_password, :required_method, :some_required_method)
        dialog.store_path(:dialogs, :customize, :fields, :root_password, :required, true)
        dialog.store_path(:dialogs, :customize, :fields, :root_password, :display, :hide)

        expect(workflow).to_not receive(:some_required_method)
        expect(workflow.validate({})).to be_true
      end

      it "field visible" do
        dialog.store_path(:dialogs, :customize, :fields, :root_password, :required_method, :some_required_method)
        dialog.store_path(:dialogs, :customize, :fields, :root_password, :required, true)

        expect(workflow).to receive(:some_required_method).and_return("Some Error")
        expect(workflow.validate({})).to be_false
      end
    end
  end
end
