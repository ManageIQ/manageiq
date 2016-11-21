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

    def to_h
      text = ERB::Util.html_escape(title ? URI.unescape(title) : title) unless title.html_safe?
      node = {
        :key          => key,
        :title        => text ? text : title,
        :expand       => expand,
        :hideCheckbox => hide_checkbox,
        :addClass     => klass,
        :cfmeNoClick  => no_click,
        :select       => selected,
        :checkable    => checkable
      }
      unless tooltip.blank?
        tip = tooltip.kind_of?(Proc) ? tooltip.call : _(tooltip)
        tip = ERB::Util.html_escape(URI.unescape(tip)) unless tip.html_safe?
        node[:tooltip] = tip
      end

      node[:icon] = if image.start_with?("/")
                      image
                    elsif image =~ %r{^[a-zA-Z0-9]+/}
                      ActionController::Base.helpers.image_path(image)
                    else
                      ActionController::Base.helpers.image_path("100/#{image}")
                    end

      node
    end
  end
end
