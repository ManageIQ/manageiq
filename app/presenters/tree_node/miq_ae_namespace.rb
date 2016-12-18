module TreeNode
  class MiqAeNamespace < MiqAeNode
    include MiqAeClassHelper

    set_attribute(:image) do
      # Having a "flat" case here makes the code more readable
      # rubocop:disable LiteralInCondition
      case true
      when !@object.domain?
        '100/ae_namespace.png'
      when @object.git_enabled?
        '100/ae_git_domain.png'
      when @object.name == MiqAeDatastore::MANAGEIQ_DOMAIN
        '100/miq.png'
      when !@object.top_level_namespace
        '100/ae_domain.png'
      else
        "100/vendor-#{@object.top_level_namespace.downcase}.png"
      end
      # rubocop:enable LiteralInCondition
    end

    set_attribute(:klass) { @object.domain? && @object.enabled? ? nil : 'striketrough' }

    private

    def model
      @object.domain? ? 'MiqAeDomain' : super
    end

    def text
      title = super
      if @object.domain?
        editable_domain = editable_domain?(@object)
        enabled_domain  = @object.enabled

        unless editable_domain && enabled_domain
          title = add_read_only_suffix(title, editable_domain, enabled_domain)
        end
      end
      title
    end
  end
end
