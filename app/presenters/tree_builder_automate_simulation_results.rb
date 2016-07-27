class TreeBuilderAutomateSimulationResults < TreeBuilder
  has_kids_for Hash, [:x_get_tree_hash_kids]
  def initialize(name, type, sandbox, build = true, root = nil)
    @root = root
    super(name, type, sandbox, build)
  end

  private

  def tree_init_options(_tree_name)
    {
      :full_ids => true,
      :add_root => false,
      :expand   => true,
      :lazy     => false
    }
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:id_prefix     => "aesimulation_",
                  :autoload      => false,
                  :cfme_no_click => true,
                  :onclick       => false)
  end

  def root_options
    []
  end

  def x_get_tree_roots(_count_only = false, _options)
    objects = []
    xml = MiqXml.load(@root).root
    xml.each_element do |el|
      objects.push(get_root_elements(el, xml.index(el)))
    end
    objects
  end

  def get_root_elements(el, idx)
    if el.name == "MiqAeObject"
      title = "#{el.attributes["namespace"]} <b>/</b> #{el.attributes["class"]} <b>/</b> #{el.attributes["instance"]}"
      icon = "q"
    elsif el.name == "MiqAeAttribute"
      title = el.attributes["name"]
      icon = "attribute"
    elsif !el.text.blank?
      title = el.text
      icon = el.name.underscore
    else
      title = el.name
      icon = title.underscore.sub(/^miq_ae_service_/, '')
      el_attributes = el.attributes
    end
    object = {:id       => "e_#{idx}",
              :text     => _(title).html_safe,
              :image    => icon,
              :tip      => _(title).html_safe,
              :elements => el.each_element {|e| e},
              :addClass => "cfme-no-cursor-node"
             }
    object[:attributes] = el_attributes if el_attributes
    object
  end

  def x_get_tree_hash_kids(parent, count_only)
    kids = []
    if parent[:attributes]
      parent[:attributes].each_with_index do |k, idx|
        kids.push({:id => "a_#{idx}", :image => "attribute", :addClass => "cfme-no-cursor-node", :text => "#{k.first} <b>=</b> #{k.last}".html_safe})
      end
    end
    Array(parent[:elements]).each_with_index do |el, i|
      kids.push(get_root_elements(el, i))
    end
    count_only_or_objects(count_only, kids)
  end
end
