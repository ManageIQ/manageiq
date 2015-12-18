class MiqAeMethodVmdbObject
  attr_accessor :tag_objects
  def initialize(wrapper, options = {})
    @wrapper = wrapper
    @attributes = options.clone
    expose_columns(@attributes.keys)
  end

  def attributes
    @attributes.clone
  end

  def [](key)
    @attributes[key]
  end

  def []=(key, value)
    @attributes[key] = value
  end

  def inspect
    to_s
  end

  def tags
    @tag_objects ||= fetch_tag_objects
    @tag_objects.collect(&:name)
  end

  private

  def expose_columns(methods)
    methods.each do |m|
      define_singleton_method "#{m}" do
        @attributes[m]
      end

      define_singleton_method "#{m}=" do |value|
        unless @attributes[m] == value
          @attributes[m] = value
          @changed = true
        end
      end
    end
  end

  def fetch_tag_objects
    data = @wrapper.get_json("#{href}?expand=tags")
    @tag_objects = data['tags'].collect do |hash|
      MiqAeMethodVmdbObject.new(@wrapper, hash)
    end
  end
end
