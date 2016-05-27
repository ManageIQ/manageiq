class TreeBuilderPolicySimulation < TreeBuilder
  # exp_build_string method needed
  include ApplicationController::ExpressionHtml

  has_kids_for Hash, [:x_get_tree_hash_kids]

  def initialize (name, type, sandbox, build = true, root = nil, root_name)
    @data = root
    @root_name = root_name
    super(name, type, sandbox, build)
  end

  private

  def tree_init_options(_tree_name)
    {:lazy => false,:full_ids => true}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:id_prefix                   => 'ps_',
                  :autoload                    => true,
                  :cfme_no_click               => true,
                  :cookie_id_prefix            => "edit_treeOpenStatex",
                  :onclick                     => false,
                  :open_close_all_on_dbl_click => true)
  end

  def root_options
    ["<b>#{@root_name}</b>".html_safe, @root_name, 'vm']
  end

  def node_icon (result)
    icon = "x"
    if result == "allow"
      icon = "checkmark"
    elsif result == "N/A"
      icon = "na"
    end
    icon
  end

  def x_get_tree_roots(count_only = false, _options)
    nodes = []
    @data.each do |node|
      icon = node_icon(node["result"])
      name = "<b>" + _("Policy Profile:") + "</b> #{node['description']}"
      nodes.push ({:id       => node['id'],
                   :text     => name.html_safe,
                   :image    => icon,
                   :tip      => node['description'],
                   :policies => node['policies']})
    end
    count_only_or_objects(count_only, nodes)
  end

  def x_get_tree_hash_kids(parent, count_only)
    nodes = []
    if parent[:policies].present?
      parent[:policies].sort_by { |a| a["description"] }.each do |node|
        active_caption = node["active"] ? "" : _(" (Inactive)")
        icon = node_icon(node["result"])
        name = "<b>" + _("Policy %{caption}:") % {:caption => active_caption} + "</b> #{node['description']}"
        nodes.push ({:id         => node['id'],
                     :text       => name.html_safe,
                     :image      => icon,
                     :tip        => node['description'],
                     :conditions => node['conditions']})
      end
      if nodes.empty?
        nodes.push({:id    => nil,
                    :text  => _("Items out of scope"),
                    :image => 'blank',
                    :tip   => nil})
      end
    end
    unless parent[:scope].blank?
        if parent[:scope]["result"] == true
          icon = "checkmark"
        else
          icon = "na"
        end
        name, tip = exp_build_string(parent[:scope])
        nodes.push ({:id    => nil,
                     :text  => name.html_safe,
                     :image => icon,
                     :tip   => tip.html_safe})

    end
    unless parent[:expression].blank?
      if parent[:expression]["result"] == true
        icon = "checkmark"
      else
        icon = "na"
      end
      name, tip = exp_build_string(parent[:expression])
      nodes.push ({:id    => nil,
                   :text  => name.html_safe,
                   :image => icon,
                   :tip   => tip.html_safe})

    end
    unless parent[:conditions].blank?
    parent[:conditions].sort_by { |a| a["description"] }.each do |node|
      icon = node_icon(node["result"])
      name ="<b>" + _("Condition:") + "</b> #{node['description']}"
      nodes.push ({:id         => node['id'],
                   :text       => name.html_safe,
                   :image      => icon,
                   :tip        => node['description'],
                   :scope      => node['scope'],
                   :expression =>  node["expression"]})
      end
    end
    count_only_or_objects(count_only, nodes)
  end
end