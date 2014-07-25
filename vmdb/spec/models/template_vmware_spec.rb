require "spec_helper"

describe TemplateVmware do
  context "#cloneable?" do
    let(:template_vmware) { TemplateVmware.new }

    it "returns true" do
      expect(template_vmware.cloneable?).to eq(true)
    end
  end
end
