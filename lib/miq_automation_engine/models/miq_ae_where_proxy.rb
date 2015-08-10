class MiqAeWhereProxy
  extend Forwardable
  include Enumerable
  attr_accessor :obj_array
  delegate [:+, :length, :flatten, :first, :last, :empty?, :size, :count, :clear, :[]] => :obj_array
  delegate [:delete_if, :sort!, :reject!] => :obj_array

  ASCENDING  = 1
  DESCENDING = 2
  RE_METHOD_CALL = /^[\s]*([\.\w]+)[\s]*(?:\((.*)\))?[\s]*$/
  SUPPORTED_METHODS = {'lower' => :downcase, 'upper' => :upcase}

  def initialize(klass, hash_args = {})
    @ae_class   = klass
    @filter_by  = hash_args
    @obj_array  = nil
    @order_by   = nil
    @direction  = ASCENDING
    @method_name = nil
  end

  def order(str)
    attribute, direction = str.downcase.split
    result = RE_METHOD_CALL.match(attribute)
    raise MiqAeException::InvalidMethod, "invalid method calling syntax: [#{attribute}]" if result.nil?

    if result[2]
      raise "Unsupported Method #{result[1]}" unless SUPPORTED_METHODS.key?(result[1])
      @method_name = SUPPORTED_METHODS[result[1]]
      @order_by    = result[2]
    else
      @order_by  = attribute
    end

    @direction = DESCENDING if direction == 'desc'
    self
  end

  def each(&block)
    to_a unless @obj_array
    @obj_array.each(&block)
  end

  def to_a
    @obj_array = @order_by ? filtered_and_sorted_objects : filtered_objects
  end

  private
  
  def attributes_match?(obj)
    @filter_by.all? do |name, value|
      raise "Object #{obj.class} doesn't support #{name}" unless obj.respond_to?(name.to_sym)
      if value.class == Array
        value.include?(obj[name])
      else
        obj[name] == value
      end 
    end 
  end

  def filtered_objects
    @ae_class.find_all_by_name('*').select do |obj|
      attributes_match?(obj)
    end
  end

  def filtered_and_sorted_objects
    if @direction == ASCENDING
      filtered_objects.sort { |a, b| apply_method(a) <=> apply_method(b) }
    else
      filtered_objects.sort { |b, a| apply_method(a) <=> apply_method(b) }
    end 
  end

  def apply_method(obj)
    if @method_name
      obj[@order_by].send(@method_name)
    else
      obj[@order_by]
    end
  end
end
