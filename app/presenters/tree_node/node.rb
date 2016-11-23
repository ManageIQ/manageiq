module TreeNode
  class Node
    include ActionView::Context
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::TextHelper
    include ActionView::Helpers::CaptureHelper

    def initialize(object, parent_id, options)
      @object = object
      @parent_id = parent_id
      @options = options
    end

    def self.set_attribute(attribute, value = nil, &block)
      atvar = "@#{attribute}".to_sym

      define_method(attribute) do
        result = instance_variable_get(atvar)

        if result.nil?
          if block_given?
            args = [@object, @options, @parent_id].take(block.arity.abs)
            result = instance_exec(*args, &block)
          else
            result = value
          end
          instance_variable_set(atvar, result)
        end

        result
      end

      equals_method(attribute)
    end

    def self.set_attributes(*attributes, &block)
      attributes.each do |attribute|
        define_method(attribute) do
          result = instance_variable_get("@#{attribute}".to_sym)

          if result.nil?
            results = instance_eval(&block)
            attributes.each_with_index do |local, index|
              instance_variable_set("@#{local}".to_sym, results[index])
              result = results[index] if local == attribute
            end
          end

          result
        end

        equals_method(attribute)
      end
    end

    def self.equals_method(attribute)
      define_method("#{attribute}=".to_sym) do |result|
        instance_variable_set("@#{attribute}".to_sym, result)
      end
    end

    def title
      @object.name
    end

    def tooltip
      nil
    end

    def klass
      nil
    end

    def no_click
      nil
    end

    def selected
      nil
    end

    def checkable
      true
    end

    def expand
      @options[:open_all].present? && @options[:open_all] && @options[:expand] != false
    end

    def hide_checkbox
      @options.key?(:hideCheckbox) && @options[:hideCheckbox]
    end

    def key
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
