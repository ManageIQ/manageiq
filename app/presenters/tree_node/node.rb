module TreeNode
  class Node < NodeBuilder
    include ActionView::Context
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::TextHelper
    include ActionView::Helpers::CaptureHelper

    set_attribute(:title, &:name)
    set_attribute(:tooltip, nil)
    set_attribute(:klass, nil)
    set_attribute(:no_click, nil)
    set_attribute(:selected, nil)
    set_attribute(:checkable, true)
    set_attribute(:expand) do
      @options[:open_all].present? && @options[:open_all] && @options[:expand] != false
    end
    set_attribute(:hide_checkbox) do
      @options.key?(:hideCheckbox) && @options[:hideCheckbox]
    end
    set_attribute(:key) do
      if @object.id.nil?
        # FIXME: this makes problems in tests
        # to handle "Unassigned groups" node in automate buttons tree
        "-#{@object.name.split('|').last}"
      else
        base_class = @object.class.base_model.name # i.e. Vm or MiqTemplate
        base_class = "Datacenter" if base_class == "EmsFolder" && @object.kind_of?(Datacenter)
        base_class = "ManageIQ::Providers::Foreman::ConfigurationManager" if @object.kind_of?(ManageIQ::Providers::Foreman::ConfigurationManager)
        base_class = "ManageIQ::Providers::AnsibleTower::ConfigurationManager" if @object.kind_of?(ManageIQ::Providers::AnsibleTower::ConfigurationManager)
        prefix = TreeBuilder.get_prefix_for_model(base_class)
        cid = ApplicationRecord.compress_id(@object.id)
        "#{@options[:full_ids] && !@parent_id.blank? ? "#{@parent_id}_" : ''}#{prefix}-#{cid}"
      end
    end
  end
end
