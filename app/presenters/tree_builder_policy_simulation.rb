class TreeBuilderPolicySimulation < TreeBuilder
  # exp_build_string method needed
  include ApplicationController::ExpressionHtml

  has_kids_for Hash, [:x_get_tree_hash_kids]

  def initialize(name, type, sandbox, build = true, root = nil, root_name, options)
    @data = root
    @root_name = root_name
    @policy_options = options
    super(name, type, sandbox, build)
  end

  private

  def tree_init_options(_tree_name)
    {:lazy => false, :full_ids => true}
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

  def node_icon(result)
    case result
    when "allow" then "checkmark"
    when "N/A"   then 'na'
    else              'x'
    end
  end

  def x_get_tree_roots(count_only = false, _options)
    if @data.present?
      nodes = @data.reject do |node|
        @policy_options[:out_of_scope] == false && node["result"] == "N/A"
      end.map do |node|
        icon = node_icon(node["result"])
        name = "<b>" + _("Policy Profile:") + "</b> #{node['description']}"
        {:id       => node['id'],
         :text     => name.html_safe,
         :image    => icon,
         :tip      => node['description'],
         :policies => node['policies']}
      end
    else
      nodes = [{:id => nil, :text => _("Items out of scope"), :image => 'blank', :cfmeNoClick => true}]
    end
    count_only_or_objects(count_only, nodes)
  end

  def skip_node(node)
    if @policy_options[:out_of_scope] == true && node["result"] != "N/A"
      return false
    elsif @policy_options[:passed] == true && node["result"] != "allow"
      return false
    elsif @policy_options[:passed] == false && @policy_options[:failed] == true && node["result"] != "deny"
      return false
    end
    true
  end

  def policy_nodes(parent)
    parent[:policies].reject { |node| skip_node(node) }.sort_by { |a| a["description"] }.map do |node|
      active_caption = node["active"] ? "" : _(" (Inactive)")
      icon = node_icon(node["result"])
      name = "<b>" + _("Policy%{caption}: ") % {:caption => active_caption} + "</b> #{node['description']}"
      {:id         => node['id'],
       :text       => name.html_safe,
       :image      => icon,
       :tip        => node['description'],
       :scope      => node['scope'],
       :conditions => node['conditions']}
    end
  end

  def condition_node(parent)
    parent[:conditions].reject do |node|
      @policy_options[:out_of_scope] == false && node["result"] == "N/A"
    end.sort_by { |a| a["description"] }.map do |node|
      icon = node_icon(node["result"])
      name = "<b>" + _("Condition: ") + "</b> #{node['description']}"
      {:id         => node['id'],
       :text       => name.html_safe,
       :image      => icon,
       :tip        => node['description'],
       :scope      => node['scope'],
       :expression => node["expression"]}
    end.compact
  end

  def scope_node(parent)
    icon = parent[:scope]["result"] ? "checkmark" : "na"
    name, tip = exp_build_string(parent[:scope])
    name = "<b>" + _("Scope: ") + "</b> " + name
    {:id => nil, :text => name.html_safe, :image => icon, :tip => tip.html_safe}
  end

  def expression_node(parent)
    icon = parent[:expression]["result"] ? "checkmark" : "na"
    name, tip = exp_build_string(parent[:expression])
    name = "<b>" + _("Expression: ") + "</b> " +  name
    {:id => nil, :text => name.html_safe, :image => icon, :tip => tip.html_safe}
  end

  def x_get_tree_hash_kids(parent, count_only)
    nodes = []
    nodes.concat(policy_nodes(parent)) unless parent[:policies].blank?
    nodes.concat(condition_node(parent)) unless parent[:conditions].blank?
    if parent[:scope].present? && @policy_options[:out_of_scope] && parent[:scope]["result"] != "N/A"
      nodes.push(scope_node(parent))
    end
    if parent[:expression].present? && @policy_options[:out_of_scope] && parent[:expression]["result"] != "N/A"
      nodes.push(expression_node(parent))
    end
    count_only_or_objects(count_only, nodes)
  end
end
