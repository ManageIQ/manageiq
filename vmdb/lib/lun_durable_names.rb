
class LunDurableName
  attr_accessor :namespace, :namespace_id, :data

  def initialize(vimDn=nil)
    return if vimDn.nil?

    unless vimDn.respond_to?(:xsiType) && vimDn.xsiType == 'ScsiLunDurableName'
      raise "#{self.class.name}: Arg is not a VIM ScsiLunDurableName object"
    end

    @namespace    = vimDn.namespace.to_s
    @namespace_id = vimDn.namespaceId.to_i
    @data     = vimDn.data.collect(&:to_i).pack("C" * vimDn.data.length) unless vimDn.data.nil?
  end

  def ==(other)
    other = self.class.new(other) unless other.kind_of?(self.class)
    @namespace == other.namespace && @namespace_id == other.namespace_id && @data == other.data
  end
end

class LunDurableNames < Array
  def initialize(vimDnArray=nil)
    super()
    return if vimDnArray.nil?
    vimDnArray.each { |vdn| self << LunDurableName.new(vdn) }
  end
end
