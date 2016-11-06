module TreeNode
  class Compliance < Node
    set_attribute(:title) do
      capture do
        concat content_tag(:strong, "#{_('Compliance Check on')}: ")
        concat format_timezone(@object.timestamp, Time.zone, 'gtl')
      end
    end

    set_attribute(:image) { "100/#{@object.compliant ? "check" : "x"}.png" }
  end
end
