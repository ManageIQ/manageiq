module TreeNode
  class Compliance < Node
    set_attribute(:title) do
      "<b>#{_('Compliance Check on')}:</b> #{format_timezone(@object.timestamp, Time.zone, 'gtl')}".html_safe
    end

    set_attribute(:image) { "100/#{@object.compliant ? "check" : "x"}.png" }
  end
end
