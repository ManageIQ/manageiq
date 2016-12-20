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
    locals.merge!(:autoload => false)
  end

  def root_options
    []
  end

  def x_get_tree_roots(_count_only = false, _options = {})
    objects = []
    xml = MiqXml.load(@root).root
    xml.each_element do |el|
      objects.push(get_root_elements(el, xml.index(el)))
    end
    objects
  end

  def choose_correct_attr(el, attrs)
    if el.name == "MiqAeObject"
      attrs[:MiqAeObject]
    elsif el.name == "MiqAeAttribute"
      attrs[:MiqAeAttribute]
    elsif !el.text.blank?
      attrs[:not_blank]
    else
      attrs[:other]
    end
  end

  def get_element_title(el)
    titles = {
      :MiqAeObject    => "#{el.attributes["namespace"]} <b>/</b> "\
                         "#{el.attributes["class"]} <b>/</b> "\
                         "#{el.attributes["instance"]}",
      :MiqAeAttribute => el.attributes["name"],
      :not_blank      => el.text,
      :other          => el.name,
    }
    choose_correct_attr(el, titles)
  end

  def get_element_icon(el)
    icons = {
      :MiqAeObject    => "100/q.png",
      :MiqAeAttribute => "100/attribute.png",
      :not_blank      => "100/#{el.name.underscore}.png",
      :other          => "100/#{el.name.underscore.sub(/^miq_ae_service_/, '')}.png",
    }
    choose_correct_attr(el, icons)
  end

  def get_root_elements(el, idx)
    title = get_element_title(el)
    object = {:id          => "e_#{idx}",
              :text        => _(title).html_safe,
              :image       => get_element_icon(el),
              :tip         => _(title).html_safe,
              :elements    => el.each_element { |e| e },
              :cfmeNoClick => true
             }
    object[:attributes] = el.attributes if title == el.name
    object
  end

  def x_get_tree_hash_kids(parent, count_only)
    kids = []
    if parent[:attributes]
      parent[:attributes].each_with_index do |k, idx|
        object = {
          :id          => "a_#{idx}",
          :image       => "100/attribute.png",
          :cfmeNoClick => true,
          :text        => "#{k.first} <b>=</b> #{k.last}".html_safe
        }
        kids.push(object)
      end
    end
    Array(parent[:elements]).each_with_index do |el, i|
      kids.push(get_root_elements(el, i))
    end
    count_only_or_objects(count_only, kids)
  end
end
