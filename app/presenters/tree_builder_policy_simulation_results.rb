class TreeBuilderPolicySimulationResults < TreeBuilder
  # exp_build_string method needed
  include ApplicationController::ExpressionHtml
  # Necessary for content_tag, concat and capture
  include ActionView::Context
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::CaptureHelper

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
     "event-#{event.name}",
     {:cfmeNoClick => true}]
  end

  def node_icon(result)
    case result
    when 'allow' then 'checkmark'
    when 'N/A'   then 'na'
    else 'x'
    end
  end

 def prefixed_title(prefix, title)
    capture do
      concat content_tag(:strong, "#{prefix}:")
      concat ' '
      concat title
    end
  end

  def vm_nodes(data)
    data.sort_by! { |a| a[:name].downcase }.map do |node|
      {:id          => node[:id],
       :text        => prefixed_title(_('VM'), node[:name]),
       :image       => 'vm',
       :profiles    => node[:profiles],
       :cfmeNoClick => true}
    end
  end

  def profile_nodes(data)
    data.sort_by! { |a| a[:description].downcase }.map do |node|
      {:id          => node[:id],
       :text        => prefixed_title(_('Profile'), node[:description]),
       :image       => node_icon(node[:result]),
       :policies    => node[:policies],
       :cfmeNoClick => true}
    end
  end

  def policy_nodes(data)
    data.sort_by! { |a| a[:description].downcase }.map do |node|
      active_caption = node[:active] ? "" : _(" (Inactive)")
      {:id          => node['id'],
       :text        => prefixed_title("#{_('Policy')}#{active_caption}", node[:description]),
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
       :text        => prefixed_title(_('Action'), node[:description]),
       :image       => node_icon(node[:result]),
       :cfmeNoClick => true}
    end
  end

  def condition_nodes(data)
    data.map do |node|
      {:id          => node[:id],
       :text        => prefixed_title(_('Condition'), node[:description]),
       :image       => node_icon(node[:result]),
       :expression  => node[:expression],
       :cfmeNoClick => true}
    end
  end

  def scope_node(data)
    name, tip = exp_build_string(data)
    {:id          => nil,
     :text        => prefixed_title(_('Scope'), name),
     :tip         => tip.html_safe,
     :image       => node_icon(data[:result]),
     :cfmeNoClick => true}
  end

  def expression_node(data)
    name, tip = exp_build_string(data)
    image = case data["result"]
            when true
              'checkmark'
            when false
              'x'
            else
              'na'
            end
    {:id          => nil,
     :text        => prefixed_title(_('Expression'), name),
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
