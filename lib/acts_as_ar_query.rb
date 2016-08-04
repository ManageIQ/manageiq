require 'forwardable'
# allow active record dsl to call legacy find
class ActsAsArQuery
  extend Forwardable
  include Enumerable
  attr_accessor :klass, :mode, :options

  # - [ ] bind
  # - [ ] create_with
  # - [ ] distinct
  # - [ ] eager_load
  # - [X] except ? - is this not defined in the interface?
  # - [ ] extending
  # - [ ] from
  # - [X] group
  # - [ ] ~~having~~ - NO
  # - [X] includes (partial)
  # - [ ] joins
  # - [X] limit
  # - [ ] lock
  # - [.] none
  # - [X] offset
  # - [X] order (partial)
  # - [ ] preload
  # - [ ] readonly
  # - [X] references (partial)
  # - [X] reorder
  # - [ ] reverse_order
  # - [X] select (partial)
  # - [X] unscope
  # - [ ] uniq
  # - [X] where (partial)
  # - [ ] where.not

  def initialize(model, opts = {})
    @klass   = model
    @options = opts || {}
  end

  def where(*val)
    val = val.flatten.compact
    val = val.first if val.size == 1 && val.first.kind_of?(Hash)
    dup.tap do |r|
      old_where = r.options[:where]
      if val.blank?
        # nop
      elsif old_where.blank?
        r.options[:where] = val
      elsif old_where.kind_of?(Hash) && val.kind_of?(Hash)
        val.each_pair do |key, value|
          old_where[key] = if old_where[key]
                             Array.wrap(old_where[key]) + Array.wrap(value)
                           else
                             value
                           end
        end
      else
        raise ArgumentError,
              "Need to support #{__callee__}(#{val.class.name}) with existing #{old_where.class.name}"
      end
    end
  end

  def includes(*args)
    append_hash_array_arg :includes, {}, *args
  end

  def references(*args)
    append_hash_array_arg :references, {}, *args
  end

  def limit(val)
    assign_arg :limit, val
  end

  def limit_value
    options[:limit]
  end

  def order(*args)
    append_hash_array_arg :order, "ASC", *args
  end

  def order_values
    options[:order] || []
  end

  def group(*args)
    append_hash_arg :group, *args
  end

  def reorder(*val)
    val = val.flatten.compact
    if val.first.kind_of?(Hash)
      raise ArgumentError, "Need to support #{__callee__}(#{val.class.name})"
    end

    dup.tap do |r|
      r.options[:order] = val
    end
  end

  def except(*val)
    dup.tap do |r|
      val.flatten.compact.each do |key|
        r.options.delete(key)
      end
    end
  end

  # similar to except. difference being this persists across merges
  def unscope(*val)
    dup.tap do |r|
      val.flatten.compact.each do |key|
        r.options[key] = nil
      end
    end
  end

  def offset(val)
    assign_arg :offset, val
  end

  def offset_value
    options[:offset]
  end

  # @param val [Array<Sting,Symbol>,String, Symbol]
  def select(*args)
    append_hash_arg :select, *args
  end

  def to_a
    @results ||= klass.find(:all, legacy_options)
  end

  def all
    self
  end

  def find(mode, options = {})
    klass.find(mode, legacy_options.merge(options))
  end

  # count(:all) is very common
  # but [1, 2, 3].count(:all) == 0
  def count(*_args)
    to_a.size
  end

  def_delegators :to_a, :size, :length, :take, :each, :empty?, :presence

  # TODO: support arguments
  def first
    defined?(@results) ? @results.first : klass.find(:first, legacy_options)
  end

  # TODO: support arguments
  def last
    defined?(@results) ? @results.last : klass.find(:last, legacy_options)
  end

  def instances_are_derived?
    true
  end

  private

  def dup
    self.class.new(klass, options.dup)
  end

  # NOTE: :references is not a legacy option
  # but it is not used in our aaarm either
  def legacy_options
    {
      :conditions => options[:where],
      :include    => options[:includes],
      :limit      => options[:limit],
      :order      => options[:order],
      :offset     => options[:offset],
      :select     => options[:select],
      :group      => options[:group],
    }.delete_blanks
  end

  def append_hash_arg(symbol, *val)
    val = val.flatten.compact
    if val.first.kind_of?(Hash)
      raise ArgumentError, "Need to support #{symbol}(#{val.class.name})"
    end
    dup.tap do |r|
      r.options[symbol] = r.options[symbol] ? (r.options[symbol] + val) : val
    end
  end

  def append_hash_array_arg(symbol, default, *val)
    val = val.flatten.compact
    val = val.first if val.size == 1 && val.first.kind_of?(Hash)
    dup.tap do |r|
      r.options[symbol] = merge_hash_or_array(r.options[symbol], val, default)
    end
  end

  # @param a [Array, Hash]
  # @param b [Array, Hash]
  # @param default default value for conversion to a hash. e.g.: {} or "ASC"
  def merge_hash_or_array(a, b, default = {})
    if a.blank?
      b
    elsif b.blank?
      a
    elsif a.kind_of?(Array) && b.kind_of?(Array)
      a + b
    else
      a = array_to_hash(a, default) if a.kind_of?(Array)
      b = array_to_hash(b, default) if b.kind_of?(Array)
      a.merge(b)
    end
  end

  def array_to_hash(arr, default = {})
    arr.each_with_object({}) { |k, h| h[k] = default.dup }
  end

  def assign_arg(symbol, val)
    dup.tap do |r|
      r.options[symbol] = val
    end
  end
end
