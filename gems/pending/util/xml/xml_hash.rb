require 'enumerator'
require 'rexml/document'
require 'util/xml/xml_utils'

module XmlHash
  class Element < Hash
    include Enumerable

    def initialize(name, attrs = {}, parent = nil)
      super()
      self.merge!(:name       => name.nil? ? nil : name.to_sym,
                  :parent     => parent,
                  :child      => [],
                  :attributes => Attributes.new(attrs),
                  :text       => nil,
                  :cdata      => nil)
    end

    def parent
      self[:parent]
    end

    def parent=(obj)
      self[:parent] = obj
    end

    def root
      root = self
      while root.parent && root.parent.kind_of?(XmlHash::Element)
        root = root.parent
      end
      root
    end

    def document
      root = self
      while root.parent
        root = root.parent
      end
      root
    end

    alias_method :doc, :document

    def name
      self[:name]
    end

    def attributes
      self[:attributes]
    end

    def text
      if self[:cdata].nil?
        self[:text]
      else
        self[:cdata][0].to_s
      end
    end

    def text=(value)
      self[:text] = value
    end

    def add_text(value)
      self.text = value
    end

    def children
      self[:child]
    end

    def add_element(name, attrs = {})
      new_node = XmlHash::Element.new(name, attrs, self)
      self[:child] << new_node
      new_node
    end

    def add_attributes(attrs)
      attrs.each_pair { |k, v| self[:attributes][k.to_sym] = v }
    end

    def add_attribute(key, value)
      add_attributes(key => value)
    end

    def write(io = STDOUT, indent = 0, _transitive = false, _ie_hack = false)
      if io.respond_to?(:write)
        io.write to_string(indent)
      else
        io << to_string(indent)
      end
      indent += 2
      self[:child].each { |n| n.write(io, indent) }
    end

    def to_s
      to_string
    end

    def to_string(indent = nil)
      text = self[:cdata].nil? ? self[:text] : "<![CDATA[#{self[:cdata]}]]>"
      if indent
        "#{self[:name].to_s.rjust(indent + self[:name].to_s.length)} #{self[:attributes].inspect} #{text}\n"
      else
        "#{self[:name]} #{self[:attributes].inspect} #{text}"
      end
    end

    def each
      self[:child].each { |n| yield(n) }
    end

    def each_element(name = nil, &_block)
      name = name.to_sym if name
      each { |e| yield e if  name.nil? || e.name == name }
    end

    def each_recursive(&block) # :yields: node
      each_element { |node| block.call(node); node.each_recursive(&block) }
    end

    def each_element_with_attribute(key, value = nil, max = 0, _name = nil, &_block) # :yields: Element
      # Note: optional "name" parameter is not implemented here.
      eCount = 0
      each do |e|
        if e.attributes.key?(key) && (value.nil? || e.attributes[key] == value)
          yield e
          eCount += 1
        end
        break if max > 0 && eCount >= max
      end
    end

    def to_xml(xml = nil)
      if xml.nil?
        return REXML::Document.new(nil) if self[:name].nil?
        xml = REXML::Document.new("<#{self[:name]}/>")
        xml = xml.root
      else
        xml = xml.add_element(self[:name].to_s)
      end

      # Convert attributes hash to string keys and set text
      xml.add_attributes(self[:attributes].inject({}) { |h, (k, v)| h[k.to_s] = v; h }) unless self[:attributes].empty?
      xml.text = self[:text] unless self[:text].nil?
      xml.add_cdata(self[:cdata][0]) unless self[:cdata].nil?

      # Add child elements
      self[:child].each { |n| n.to_xml(xml) }
      xml.document
    end

    def ==(obj)
      object_id == obj.object_id
    end

    def to_h(options = {}, type = :simple)
      send("to_h_#{type}", options, nil)
    end

    def to_h_simple(options, hash = nil)
      hash = {} if hash.nil?

      each do |c|
        e = (hash[options[:symbols] == false ? c.name.to_s : c.name] ||= []) << (options[:symbols] == false ? XmlHelpers.stringify_keys(c.attributes) : c.attributes)
        e.last[options[:symbols] == false ? 'content' : :content] = c.text if c.text
        c.to_h_simple(options, e.last)
      end

      hash
    end

    def elements
      return @elements if @elements
      @elements = Elements.new(self)
    end

    def has_elements?
      !children.empty?
    end

    def get_path
      p = parent
      head = nil
      while p && p.name && p.kind_of?(XmlHash::Element)
        # Create a "shallow copy" of the current element (does not copy child elements)
        newEle = p.shallow_copy(false)

        if head.nil?
          head = newEle
        else
          newEle << head
          head = newEle
        end

        p = p.parent
      end
      head
    end

    def shallow_copy(include_text = false)
      newEle = XmlHash::Element.new(name)
      newEle.add_attributes(attributes)
      newEle.text = text if include_text
      newEle
    end

    def <<(rhs)
      if rhs.parent.nil? || rhs.class == XmlHash::Document
        self.child = rhs
      else
        rhs.remove!
        return self.child = rhs
      end
    end

    alias_method :add, :<<

    def child=(object)
      if object.kind_of?(Hash)
        x = self[:child] << object
        object.parent = self
      elsif object.respond_to?(:to_xml)
      else
        raise "Invalid child object type [#{object.class}] for XmlHash"
      end
    end

    def remove!
      if parent
        parent.children.delete(self) if parent
        self.parent = nil
      end
    end

    def delete(element)
      element.remove!
    end
    alias_method :delete_element, :delete

    def add_elements_from_xml(xml)
      xml.each_element do |e|
        xmh = add_element(e.name)
        e.attributes.each_pair { |k, v| xmh.add_attribute(k, v.to_s) }
        if e.cdatas.empty?
          xmh.text = e.text if e.text && !e.text.strip.length.zero?
        else
          xmh.cdata = e.cdatas
        end
        xmh.add_elements_from_xml(e)
      end
    end

    def from_hash(ref, options)
      ref.each_pair do |k, v|
        case v
        when Array
          v.each do |h|
            e = add_element(k)
            e.from_hash(h, options)
          end
        else
          if k.to_sym == options[:ContentKey]
            self.text = v
          else
            add_attribute(k, v)
          end
        end
      end
    end

    def cdatas
      self[:cdata]
    end

    def cdata=(data)
      self[:cdata] = [*data]
    end

    def add_cdata(data)
      self.cdata = data
    end

    def key_type
      Symbol
    end

    def find_first(_xpath, _ns = nil)
      raise "Method [find_first] not supported in Class #{self.class}"
    end

    def find_each(_name, &_blk)
      raise "Method [find_each] not supported in Class #{self.class}"
    end

    def find_match(_name, &_blk)
      raise "Method [find_match] not supported in Class #{self.class}"
    end

    def self.newNode(data = nil)
      new(data)
    end
  end

  # There is no difference between a document and an element here
  class Document < Hash
    require 'util/xml/xml_diff'
    require 'util/xml/xml_patch'

    include MiqXmlDiff
    include MiqXmlPatch

    def initialize(name = "xml", _attrs = {}, _parent = nil)
      super()
      self.merge!(:name     => name.to_sym,
                  :child    => [],
                  :encoding => "UTF-8",
                  :version  => 1.0)
    end

    def elements
      return @elements if @elements
      @elements = Elements.new(self)
    end

    def parent
      nil
    end

    def parent=(obj)
      self[:parent] = obj
    end

    def root
      self[:child][0]
    end

    def root=(rhs)
      self[:child].clear
      self[:child] << rhs
      rhs.parent = self
      rhs
    end

    def document
      self
    end

    alias_method :doc, :document

    def name
      self[:name]
    end

    def children
      self[:child]
    end

    def add_element(*args)
      self.root = XmlHash::Element.new(*args)
      root.parent = self
      root
    end

    def each_element(name = nil, &_block)
      self[:child].each { |e| yield e if  name.nil? || e.name == name }
    end

    def to_h(*args)
      return nil if self[:child].first.nil?
      self[:child].first.to_h(*args)
    end

    def write(*args)
      root.write(*args)
    end

    def to_xml(*args)
      return REXML::Document.new(nil) if root.nil?
      root.to_xml(*args)
    end

    def extendXmlDiff; end

    def miqEncode
      MIQEncode.encode(to_xml.to_s)
    end

    def deep_clone
      to_xml.write(buf = '', 0)
      self.class.load(buf)
    end

    def find_first(_xpath, _ns = nil)
      raise "Method [find_first] not supported in Class #{self.class}"
    end

    def find_each(_name, &_blk)
      raise "Method [find_each] not supported in Class #{self.class}"
    end

    def find_match(_name, &_blk)
      raise "Method [find_match] not supported in Class #{self.class}"
    end

    def self.from_xml(xml_data)
      # Handle converting data of different types
      case xml_data
      when String, File, NilClass
        xml = REXML::Document.new(xml_data)
      when REXML::Document
        xml = xml_data
      when REXML::Element
        xml = xml_data.document
      when XmlHash::Document, XmlHash::Element
        return xml_data.doc
      when Symbol
        xml = REXML::Document.createDoc(xml_data)
      end

      xmh_doc = XmlHash::Document.new
      return xmh_doc if xml.root.nil?
      xmh = XmlHash::Element.new(xml.root.name)
      xml.root.attributes.each_pair { |k, v| xmh.add_attribute(k, v.to_s) }
      xmh.add_elements_from_xml(xml.root)
      xmh_doc.root = xmh
      xmh_doc
    end

    def self.createDoc(*args)
      xml = REXML::Document.createDoc(*args)
      load(xml)
    end

    def self.load(*args)
      from_xml(*args)
    end

    def self.loadFile(filename)
      f = nil
      f = File.open(filename, "r")
      load(f)
    ensure
      f.close if f
    end

    def self.from_hash(ref, options = {})
      options = {:rootname => :opt, :root_attrs => {}, :ContentKey => :content}.merge(options)
      xmh = XmlHash::Document.new(options[:rootname])
      xmh.add_element(options[:rootname], options[:root_attrs])
      xmh.root.from_hash(ref, options)
      xmh
    end

    def self.newDoc(*args)
      new(*args)
    end

    def self.newNode(data = nil)
      XmlHash::Element.new(data)
    end
  end

  # Create an Elements class to support Element[#] were # is 1 based.  (Stupid REXML)
  class Elements
    def initialize(parent)
      @element = parent
    end

    def [](index, _name = nil)
      if index.kind_of? Integer
        raise "index (#{index}) must be >= 1" if index < 1
        return @element.children[index - 1]
      else
        p = nil
        @element.children.each do |e|
          if e.name == index.to_sym
            p = e
            break
          end
        end
        return p
      end
    end

    def <<(rhs)
      @element << rhs
    end

    def each
      return if @element.nil?
      @element.each { |n| yield(n) }
    end
  end

  class Attributes < Hash
    def initialize(attrs = nil)
      super(nil)
      attrs.each_pair { |k, v| self[k.to_sym] = v } unless attrs.nil?
    end

    alias_method :each_attrib, :each

    def to_h
      self
    end

    def [](name)
      super(name.to_sym)
    end

    def []=(name, value)
      super(name.to_sym, value)
    end
  end

  class XmhHelpers
    def self.findRegElementInt(paths, ele)
      if paths.length > 0
        searchStr = paths[0].downcase
        paths = paths[1..paths.length]
        # puts "Search String: #{searchStr}"
        ele.each_element do |e|
          # puts "Current String: [#{e.name.to_s.downcase}] [#{e.attributes[:keyname].to_s.downcase}] [#{e.attributes[:name].to_s.downcase}]"
          if e.name.to_s.downcase == searchStr || (!e.attributes[:keyname].nil? && e.attributes[:keyname].downcase == searchStr) || (!e.attributes[:name].nil? && e.attributes[:name].downcase == searchStr)
            # puts "String Found: [#{e.name}] [#{e.attributes[:name]}]"
            return findRegElementInt(paths, e)
          end # if
        end # do
        return nil if paths.length == 0
      else
        return ele
      end
    end

    def self.findElementInt(paths, ele)
      if paths.length > 0
        found = false
        searchStr = paths[0]
        paths = paths[1..paths.length]
        # puts "Search String: #{searchStr}"
        ele.each_element do |e|
          # puts "Current String: [#{e.name.to_s.downcase}] - [#{e.attributes[:keyname]}] - [#{e.attributes[:name]}]"
          if e.name.to_s.downcase == searchStr.downcase || (!e.attributes[:keyname].nil? && e.attributes[:keyname].downcase == searchStr.downcase) || (!e.attributes[:name].nil? && e.attributes[:name].downcase == searchStr.downcase)
            # puts "String Found: [#{e.name}]"
            return findElementInt(paths, e)
          end # if
        end # do
      else
        return ele
      end
      nil
    end
  end

  # Module helper methods
  def self.createDoc(*args)
    self::Document.from_xml(*args)
  end

  def self.load(*args)
    self::Document.from_xml(*args)
  end

  def self.loadFile(*args)
    self::Document.loadFile(*args)
  end

  def self.from_hash(*args)
    self::Document.from_hash(*args)
  end

  def self.newDoc(*args)
    self::Document.new(*args)
  end

  def self.newNode(data = nil)
    self::Document.newNode(data)
  end
end
