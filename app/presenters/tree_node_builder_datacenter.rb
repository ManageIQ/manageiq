class TreeNodeBuilderDatacenter < TreeNodeBuilder
  # Adding type of node as prefix to nodes without tooltip and (Click to view) as suffix to all
  def tooltip(tip)
    if tip.blank? && @options[:tooltip_forced]
      tip = object.name
      if @options[:tooltip_prefix_type]
        prefix = @options[:tooltip_prefix_type]
        prefix_type = prefix[0].send(prefix[1], object)

        tip = "#{prefix_type}: #{tip}" if prefix_type.present?
      end
    elsif tip.present?
      tip = tip.kind_of?(Proc) ? tip.call : _(tip)
      end
      if tip && @options[:tooltip_suffix]
      tip += @options[:tooltip_suffix]
    end

    tip = ERB::Util.html_escape(URI.unescape(tip)) unless tip.nil? || tip.html_safe?
    @node[:tooltip] = tip
  end
end