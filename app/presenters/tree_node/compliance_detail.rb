module TreeNode
  class ComplianceDetail < Node
    set_attribute(:title) do
      "<b>#{_('Policy')}:</b> #{@object.miq_policy_desc}".html_safe
    end

    set_attribute(:image) { "100/#{@object.miq_policy_result ? "check" : "x"}.png" }
  end
end
