class TreeBuilderPolicySimulationResults < TreeBuilder
  # exp_build_string method needed
  include ApplicationController::ExpressionHtml

  has_kids_for Hash, [:x_get_tree_hash_kids]

  def initialize(name, type, sandbox, build = true, root = nil)
    @root = root
    super(name, type, sandbox, build)
  end

  private

  def tree_init_options(_tree_name)
    {:full_ids => true, :lazy => false}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:autoload => true)
  end

  def root_options
    event = MiqEventDefinition.find(@root[:event_value])
    [_("Policy Simulation Results for Event [%{description}]") % {:description => event.description},
     nil,
     "100/event-#{event.name}.png",
     {:cfmeNoClick => true}]
  end

  def node_icon(result)
    case result
    when 'allow' then '100/checkmark.png'
    when 'N/A'   then '100/na.png'
    else '100/x.png'
    end
  end

  def vm_nodes(data)
    data.sort_by! { |a| a[:name].downcase }.map do |node|
      {:id          => node[:id],
       :text        => "<strong>VM:</strong> #{node[:name]}".html_safe,
       :image       => '100/vm.png',
       :profiles    => node[:profiles],
       :cfmeNoClick => true}
    end
  end

  def profile_nodes(data)
    data.sort_by! { |a| a[:description].downcase }.map do |node|
      {:id          => node[:id],
       :text        => "<strong>#{_('Profile:')}</strong> #{node[:description]}".html_safe,
       :image       => node_icon(node[:result]),
       :policies    => node[:policies],
       :cfmeNoClick => true}
    end
  end

  def policy_nodes(data)
    data.sort_by! { |a| a[:description].downcase }.map do |node|
      active_caption = node[:active] ? "" : _(" (Inactive)")
      {:id          => node['id'],
       :text        => "<strong>#{_('Policy')}#{active_caption}:</strong> #{node[:description]}".html_safe,
       :image       => node_icon(node[:result]),
       :conditions  => node[:conditions],
       :actions     => node[:actions],
       :scope       => node[:scope],
       :cfmeNoClick => true}
    end
  end

  def action_nodes(data)
    data.map do |node|
      {:id          => node[:id],
       :text        => "<strong>#{_('Action:')}</strong> #{node[:description]}".html_safe,
       :image       => node_icon(node[:result]),
       :cfmeNoClick => true}
    end
  end

  def condition_nodes(data)
    data.map do |node|
      {:id          => node[:id],
       :text        => "<strong>#{_('Condition:')}</strong> #{node[:description]}".html_safe,
       :image       => node_icon(node[:result]),
       :expression  => node[:expression],
       :cfmeNoClick => true}
    end
  end

  def scope_node(data)
    name, tip = exp_build_string(data)
    {:id          => nil,
     :text        => "<strong>#{_('Scope:')}</strong> <span class='ws-wrap'>#{name}".html_safe,
     :tip         => tip.html_safe,
     :image       => node_icon(data[:result]),
     :cfmeNoClick => true}
  end

  def expression_node(data)
    name, tip = exp_build_string(data)
    image = case data["result"]
            when true
              '100/checkmark.png'
            when false
              '100/x.png'
            else
              '100/na.png'
            end
    {:id          => nil,
     :text        => "<strong>#{_('Expression:')}</strong> <span class='ws-wrap'>#{name}".html_safe,
     :tip         => tip.html_safe,
     :image       => image,
     :cfmeNoClick => true}
  end

  def x_get_tree_roots(count_only = false, _options = nil)
    count_only_or_objects(count_only, vm_nodes(@root[:results]))
  end

  def x_get_tree_hash_kids(parent, count_only)
    kids = []
    kids.concat(profile_nodes(parent[:profiles])) if parent[:profiles].present?
    kids.concat(policy_nodes(parent[:policies])) if parent[:policies].present?
    kids.concat(condition_nodes(parent[:conditions])) if parent[:conditions].present?
    kids.push(scope_node(parent[:scope])) if parent[:scope].present?
    kids.push(expression_node(parent[:expression])) if parent[:expression].present?
    kids.concat(action_nodes(parent[:actions])) if parent[:actions].present?
    count_only_or_objects(count_only, kids)
  end
end
