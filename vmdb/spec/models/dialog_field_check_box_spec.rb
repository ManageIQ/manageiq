require "spec_helper"

describe DialogFieldCheckBox do
  describe "#validate" do
    let(:dialog_field_check_box) do
      described_class.new(:label    => 'dialog_field_check_box',
                          :name     => 'dialog_field_check_box',
                          :required => required,
                          :value    => value)
    end
    let(:dialog_tab)   { active_record_instance_double('DialogTab',   :label => 'tab') }
    let(:dialog_group) { active_record_instance_double('DialogGroup', :label => 'group') }

    shared_examples_for "DialogFieldCheckBox#validate that returns nil" do
      it "returns nil" do
        dialog_field_check_box.validate(dialog_tab, dialog_group).should be_nil
      end
    end

    context "when required is true" do
      let(:required) { true }

      context "with a true value" do
        let(:value) { "t" }

        it_behaves_like "DialogFieldCheckBox#validate that returns nil"
      end

      context "with a false value" do
        let(:value) { "f" }

        it "returns error message" do
          dialog_field_check_box.validate(dialog_tab, dialog_group).should eq(
            "tab/group/dialog_field_check_box is required"
          )
        end
      end
    end

    context "when required is false" do
      let(:required) { false }

      context "with a true value" do
        let(:value) { "t" }

        it_behaves_like "DialogFieldCheckBox#validate that returns nil"
      end

      context "with a false value" do
        let(:value) { "f" }

        it_behaves_like "DialogFieldCheckBox#validate that returns nil"
      end
    end
  end
end
