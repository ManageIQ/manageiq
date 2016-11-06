module TreeNode
  class MiqPolicy < Node
    set_attribute(:image) { "100/miq_policy_#{@object.towhat.downcase}#{@object.active ? '' : '_inactive'}.png" }
    set_attribute(:title) do
      if @options[:tree] == :policy_profile_tree
        capture do
          concat content_tag(:strong, "#{ui_lookup(:model => @object.towhat)} #{@object.mode.titleize}: ")
          concat ERB::Util.html_escape(@object.description)
        end
      else
        @object.description
      end
    end
  end
end
