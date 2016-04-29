require 'VMwareWebService/VimConstants'
autoload :VimMappingRegistry, 'VMwareWebService/VimMappingRegistry'

module VimType
  def vimType
    @vimType.nil? ? nil : @vimType.to_s
  end

  def vimType=(val)
    @vimType = val.nil? ? nil : val.to_sym
  end

  def vimBaseType
    VimClass.base_class(vimType)
  end

  def xsiType
    @xsiType.nil? ? nil : @xsiType.to_s
  end

  def xsiType=(val)
    @xsiType = val.nil? ? nil : val.to_sym
  end
end

class VimHash < Hash
  include VimType

  undef_method(:id)   if method_defined?(:id)
  undef_method(:type) if method_defined?(:type)
  undef_method(:size) if method_defined?(:size)
  undef_method(:key)  if method_defined?(:key)

  def initialize(xsiType = nil, vimType = nil)
    self.xsiType = xsiType
    self.vimType = vimType
    super()
    self.default = nil
    yield(self) if block_given?
  end

  def each_arg
    raise "No arg map for #{xsiType}" unless (am = VimMappingRegistry.args(xsiType))
    am.each do |a|
      next unless self.key?(a)
      yield(a, self[a])
    end
  end

  def method_missing(sym, *args)
    key = sym.to_s
    if key[-1, 1] == '='
      self[key[0...-1]] = args[0]
    else
      self[key]
    end
  end
end

class VimArray < Array
  include VimType

  def initialize(xsiType = nil, vimType = nil)
    self.xsiType = xsiType
    self.vimType = vimType
    super()
    yield(self) if block_given?
  end
end

class VimString < String
  include VimType

  #
  # vimType and xsiType arg positions are switched here because
  # most strings are MORs, and this makes it easier to set the
  # vimType of the MOR.
  #
  def initialize(val = "", vimType = nil, xsiType = nil)
    self.xsiType = xsiType
    self.vimType = vimType
    super(val)
    yield(self) if block_given?
  end
end

class VimFault < RuntimeError
  attr_accessor :vimFaultInfo

  def initialize(vimObj)
    @vimFaultInfo = vimObj
    super(@vimFaultInfo.localizedMessage)
  end
end

class VimClass
  # Default to a sparse 1:1 mapping
  @class_hierarchy = Hash.new { |hash, key| hash[key] = Set[key] }
  @base_class      = Hash.new { |hash, key| hash[key] = key }

  # Add VmwareDistributedVirtualSwitch as a child class of DistributedVirtualSwitch
  @class_hierarchy["DistributedVirtualSwitch"]  << "VmwareDistributedVirtualSwitch"
  @base_class["VmwareDistributedVirtualSwitch"] =  "DistributedVirtualSwitch"

  def self.child_classes(vim_type)
    @class_hierarchy[vim_type]
  end

  def self.base_class(vim_type)
    @base_class[vim_type]
  end
end
