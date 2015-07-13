require "spec_helper"
require Rails.root.join("db/migrate/20120828220222_add_type_to_customization_template.rb")

describe AddTypeToCustomizationTemplate do
  migration_context :up do
    let(:ct_stub)     { migration_stub(:CustomizationTemplate) }

    it "migrates all CustomizationTemplates to have type CustomizationTemplateKickstart" do
      template = ct_stub.create!

      migrate

      template.reload.type.should == 'CustomizationTemplateKickstart'
    end
  end
end
