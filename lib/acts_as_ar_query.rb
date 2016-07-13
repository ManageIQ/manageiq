require 'forwardable'
# allow active record dsl to call legacy find
class ActsAsArQuery
  extend Forwardable
  attr_accessor :klass, :mode, :options

  # methods that execute actual query

  # - [X] all
  # - [X] count
  # - [X] find
  # - [ ] find_by
  # - [X] first
  # - [X] last
  # - [X] size
  # - [X] take

  # methods that enhance / chain the query
  # list is from ActiveRecord relation interface

  # - [ ] bind
  # - [ ] create_with
  # - [ ] distinct
  # - [ ] eager_load
  # - [X] except ? - is this not defined in the interface?
  # - [ ] extending
  # - [ ] from
  # - [ ] ~~group~~ - NO
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

  # private api
  # the common pattern is to allow this method to be called frequently
  # and add the values into the hash
  # this is used by methods like includes, references, order, select and others
  def append_hash_arg(*val)
    symbol = __callee__
    val = val.flatten
    if val.first.kind_of?(Hash)
      raise ArgumentError, "Need to support #{symbol}(#{val.class.name})"
    end
    dup.tap do |r|
      r.options[symbol] = r.options[symbol] ? (r.options[symbol] + val) : val
    end
  end

  # public api

  def initialize(model, opts = {})
    @klass   = model
    @options = opts || {}
  end

  # @param val [Hash]
  # TODO [Array, Hash, String]
  def where(*val)
    val = val.flatten
    val = val.first if val.size == 1 && val[0].kind_of?(Hash)
    dup.tap do |r|
      old_where = r.options[:where]
      if val.empty?
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
              "Need to support #{__method__}(#{val.class.name}) with existing #{old_where.class.name}"
      end
    end
  end

  # @param val [Array] for includes
  # TODO: support hash
  alias includes append_hash_arg

  # @param val Array for includes
  alias references append_hash_arg

  # @param [Integer] val
  def limit(val)
    dup.tap do |r|
      r.options[:limit] = val
    end
  end

  # @param [String, Symbol, Arel] val
  # TODO: support Hash
  # TODO: support mixing?
  alias order append_hash_arg

  def reorder(*val)
    val = val.flatten
    if val.first.kind_of?(Hash)
      raise ArgumentError, "Need to support #{__callee__}(#{val.class.name})"
    end

    dup.tap do |r|
      r.options[:order] = val
    end
  end

  def except(*val)
    val = val.flatten
    dup.tap do |r|
      val.each do |key|
        r.options.delete(key)
      end
    end
  end

  # similar to except. difference being this persists across merges
  def unscope(*val)
    val = val.flatten
    dup.tap do |r|
      val.each do |key|
        r.options[key] = nil
      end
    end
  end

  # @param [Integer] val
  def offset(val)
    dup.tap do |r|
      r.options[:offset] = val
    end
  end

  # complete
  # @param val [Array<Sting,Symbol>,String, Symbol]
  alias select append_hash_arg

  # execution methods
  # these methods execue the query

  def to_a
    @results ||= klass.find(:all, legacy_options)
  end

  def all
    self
  end

  def find(mode, options)
    @results ||= klass.find(mode, legacy_options.merge(options))
  end

  # find_by()

  def count
    # klass.find(:count, legacy_options)
    to_a.size
  end
  def_delegators :to_a, :size, :take

  def first # (number)
    klass.find(:first, legacy_options)
  end

  def last
    klass.find(:last, legacy_options)
  end

  # benind the scenes

  def dup
    self.class.new(klass, options.dup)
  end

  def legacy_options
    {
      :conditions => options[:where],
      :include    => options[:includes],
      # :include  => options[:references],
      :limit      => options[:limit],
      :order      => options[:order],
      :offset     => options[:offset],
      :select     => options[:select],
    }.delete_if { |_name, value| value.blank? }
  end

  def instances_are_derived?
    true
  end
end
