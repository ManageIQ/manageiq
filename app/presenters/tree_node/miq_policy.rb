module TreeNode
  class MiqPolicy < Node
    set_attribute(:image) { "100/miq_policy_#{@object.towhat.downcase}#{@object.active ? '' : '_inactive'}.png" }
    set_attribute(:title) do
      if @options[:tree] == :policy_profile_tree
        "<strong>%{towhat} %{mode}:</strong> %{description}".html_safe % {
          :towhat      => ui_lookup(:model => @object.towhat),
          :mode        => @object.mode.titleize,
          :description => ERB::Util.html_escape(@object.description)
        }
      else
        @object.description
      end
    end
  end
end
