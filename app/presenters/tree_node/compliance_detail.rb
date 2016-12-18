module TreeNode
  class ComplianceDetail < Node
    set_attribute(:title) do
      capture do
        concat content_tag(:strong, "#{_('Policy')}: ")
        concat @object.miq_policy_desc
      end
    end

    set_attribute(:image) { "100/#{@object.miq_policy_result ? "check" : "x"}.png" }
  end
end
