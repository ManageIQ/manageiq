module TreeNode
  class MiqServer < Node
    set_attribute(:image, '100/miq_server.png')
    set_attribute(:expand, true)

    set_attributes(:title, :tooltip) do
      if @options[:is_current]
        tooltip  = _("%{server}: %{server_name} [%{server_id}] (current)") %
                   {:server => ui_lookup(:model => @object.class.to_s), :server_name => @object.name, :server_id => @object.id}
        tooltip += " (#{@object.status})" if @options[:tree] == :roles_by_server_tree
        title = content_tag(:strong, ERB::Util.html_escape(tooltip))
      else
        tooltip  = "#{ui_lookup(:model => @object.class.to_s)}: #{@object.name} [#{@object.id}]"
        tooltip += " (#{@object.status})" if @options[:tree] == :roles_by_server_tree
        title = tooltip
      end
      [title, tooltip]
    end
  end
end
