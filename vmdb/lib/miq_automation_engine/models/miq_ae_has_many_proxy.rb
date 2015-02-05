require 'forwardable'
class MiqAeHasManyProxy
  extend Forwardable
  include Enumerable
  attr_accessor :obj_array
  delegate [:+, :length, :flatten, :each, :first, :last, :empty?, :size, :count, :clear, :[]] => :obj_array
  delegate [:delete_if, :sort!, :reject!] => :obj_array
  def initialize(parent_obj, relation_options, array = [])
    @obj_array        = array
    @klass            = relation_options[:class_name].constantize
    @foreign_key      = relation_options[:foreign_key]
    @parent_obj       = parent_obj
    @belongs_to       = relation_options[:belongs_to]
    @save_parent      = relation_options.fetch(:save_parent, false)
  end

  def destroy_all
    @obj_array.each(&:destroy)
    @obj_array.clear
    @parent_obj.save if @save_parent
  end

  def <<(*obj)
    obj.flatten! if obj.class == Array
    return if obj.empty?
    raise "needs one or more #{@klass.name} objects" if obj.first.class != @klass
    obj.each { |o| belongs_to(o) }
    @obj_array.concat(obj)
    @parent_obj.save if @save_parent
  end

  def assign(*obj)
    @obj_array.clear
    obj.flatten! if obj.class == Array
    return if obj.empty?
    raise "needs one or more #{@klass.name} objects" if obj.first.class != @klass
    obj.each { |o| belongs_to(o) }
    @obj_array.concat(obj)
  end

  def build(attributes = {})
    attributes.class == Array ? build_with_array(attributes) : build_with_hash(attributes)
  end

  def build_with_array(array)
    array.each { |hash| build_with_hash(hash) }
  end

  def build_with_hash(hash)
    attrs = {"#{@belongs_to}" => @parent_obj}.merge(hash)
    @klass.build(attrs).tap  { |o| @obj_array << o }
  end
  alias_method :new, :build

  def deep_clone
    Marshal.load(Marshal.dump(self))
  end

  def create(params = {})
    params.class == Array ? params.collect { |attr| single_create(attr) } : single_create(params)
  end

  def single_create(attributes = {})
    attrs = {"#{@belongs_to}" => @parent_obj}.merge(attributes)
    @klass.create(attrs).tap  { |o| @obj_array << o }
  end

  def create!(params = {})
    params.class == Array ? params.collect { |attr| single_create!(attr) } : single_create!(params)
  end

  def single_create!(attributes = {})
    attrs = {"#{@belongs_to}" => @parent_obj}.merge(attributes)
    @klass.create!(attrs).tap  { |o| @obj_array << o }
  end

  def delete(*obj)
    obj.each do |o|
      next if o.class != @klass
      found = @obj_array.reject! { |rm| rm.id == o.id }
      found.each(&:destroy) if found
    end
    @parent_obj.save if @autosave
  end

  alias_method :destroy, :delete

  def find(*args)
    raise "Someone calling find #{args.inspect}"
  end

  def search(name_filter)
    return [] if @obj_array.empty?
    return [] unless @obj_array.first.respond_to?(:name)
    @obj_array.collect do |o|
      next unless File.fnmatch(name_filter, o.name, File::FNM_CASEFOLD | File::FNM_DOTMATCH)
      o.name
    end.compact
  end

  private

  def belongs_to(obj)
    obj.send("#{@belongs_to}=", @parent_obj)
  end
end
