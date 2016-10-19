class TreeNodeBuilderDatacenter < TreeNodeBuilder
  # Get correct prefix
  def prefix_type(object)
    case object
    when Host         then "Host"
    when EmsCluster   then "Cluster"
    when ResourcePool then "Resource Pool"
    when Datacenter   then "Datacenter"
    when Vm           then "VM"
    when Switch       then "Switch"
    else                   ""
    end
  end

  # Adding type of node as prefix to nodes without tooltip and (Click to view) as suffix to all
  def tooltip(tip)
    if tip.blank?
      tip = object.name
      prefix_type = prefix_type(object)
      tip = "#{prefix_type}: #{tip}" if prefix_type.present?
    elsif tip.present?
      tip = tip.kind_of?(Proc) ? tip.call : _(tip)
    end
    tip += _(" (Click to view)")
    tip = ERB::Util.html_escape(URI.unescape(tip)) unless tip.nil? || tip.html_safe?
    @node[:tooltip] = tip
  end

  def normal_folder_node
    icon = options[:type] == :vat ? "blue_folder.png" : "folder.png"
    generic_node(object.name, icon, "Folder: #{object.name}")
  end

  def vm_node(object)
    image = "currentstate-#{object.normalized_state.downcase}.png"
    unless object.template?
      tip = _("VM: %{name}") % {:name => object.name}
    end
    generic_node(object.name, image, tip)
  end
end
