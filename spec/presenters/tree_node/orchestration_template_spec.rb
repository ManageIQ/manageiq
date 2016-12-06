require 'shared/presenters/tree_node/common'

describe TreeNode::OrchestrationTemplate do
  subject { described_class.new(object, nil, {}) }

  {
    :orchestration_template_cfn                       => %w(OrchestrationTemplateCfn cfn),
    :orchestration_template_hot_with_content          => %w(OrchestrationTemplateHot hot),
    :orchestration_template_azure_with_content        => %w(OrchestrationTemplateAzure azure),
    :orchestration_template_vnfd_with_content         => %w(OrchestrationTemplateVnfd vnfd),
    :orchestration_template_vmware_cloud_with_content => %w(ManageIQ::Providers::Vmware::CloudManager::OrchestrationTemplate vapp)
  }.each do |factory, config|
    context(config.first) do
      let(:object) { FactoryGirl.create(factory) }

      include_examples 'TreeNode::Node#key prefix', 'ot-'
      include_examples 'TreeNode::Node#image', "100/orchestration_template_#{config.last}.png"
    end
  end
end
