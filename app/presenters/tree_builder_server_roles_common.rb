module TreeBuilderServerRolesCommon
  def x_build_single_node(object, pid, options)
    options[:parent_kls]  = @sb[:parent_kls] if @sb.try(:parent_kls)
    options[:parent_name] = @sb[:parent_name] if @sb.try(:parent_name)
    super(object, pid, options)
  end
end
