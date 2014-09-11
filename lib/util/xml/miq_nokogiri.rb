begin
  # Try to load the nokogiri library bindings.  If it fails then we skip defining the methods below.
  require 'nokogiri'
  require 'xml_diff'
  require 'xml_patch'

  # Add class methods to nokogiri to have it behave more like REXML for easy replacement
  module Nokogiri
    module XML
      class Node
        def add_attribute(key, value)
          self[key.to_s] = value.to_s unless value.nil?
        end

        def add_attributes(attr_hash)
          return unless attr_hash
          attr_hash.each_pair {|k,v| self.add_attribute(k, v)}
        end

        def add_element(element, attrs=nil)
          self << newEle = XML::Node.new(element.to_s, self.document)
          newEle.add_attributes(attrs)
          return newEle
        end

        # Note: In nokogiri the "text" method is an alias for context (and inner_text)
        #       which returns the text for this node plus all it's child nodes.
        # The node_text method only return this nodes text
        def node_text
          self.children.each do |node|
            if node.node_type == TEXT_NODE
              if node.content && node.content.rstrip.length > 0
                return node.content
              end
            end
          end
          return nil
        end

        def text=(string)
          # Find the text node and update it's content.
          self.children.each do |node|
            if node.node_type == TEXT_NODE
              node.content = string.to_s
              return node.content
            end
          end
          self << XML::Text.new(string.to_s, self.doc)
        end

        # Last two parms added to duplicate REXML write function
        # they are ignored in this method
        def write(io_handle, indent=-1, transitive=false, ie_hack=false)
          options = {:indent => (indent >= 0 ? indent : 0)}

          if String === io_handle
            io_handle.replace(self.to_xml(options))
          else
            io_handle << self.to_xml(options)
          end
        end

        def each_element (xpath="*", &block)
          self.find_match(xpath).each {|n| yield n}
        end

        def root
          return nil unless self.document
          self.document.root
        end

        def has_elements?
          # Verify there are elements, not just a text node
          self.each_element {|e| return true}
          return false
        end

        alias :doc      :document
        alias :remove!  :remove

        def find_first(xpath, ns=nil)
          self.at_xpath(*paths)
        end

        def find_each(name, &blk)
          self.xpath(name, &blk)
        end

        def find_match(xpath=nil, nslist = nil)
          xpath = "*" if xpath.nil?
          self.xpath(xpath, nslist)
        end

        def add_cdata(string)
          self << Nokogiri::XML::CDATA.new(self, string.to_s)
        end
      end  # class Node

      class Document
        #include MiqXmlDiff
        #include MiqXmlPatch

        #MIQ_XML_VERSION = 1.0
        #MIQ_XML_VERSION = 1.1	# Added create_time to root in seconds for easier time conversions
        MIQ_XML_VERSION = 2.0	# Changed sub-xmls, added namespaces

        #def extendXmlDiff; end

        # Last two parms added to duplicate REXML write function
        # they are ignored in this method
        def write(io_handle, indent=-1, transitive=false, ie_hack=false)
          options = {:indent => (indent >= 0 ? indent : 0)}

          if String === io_handle
            io_handle.replace(self.to_xml(options))
          else
            io_handle << self.to_xml(options)
          end
        end

        def miqEncode
          MIQEncode.encode(self.to_s)
        end

        def self.loadFile(filename)
          begin
            Nokogiri::XML::Document.file(filename)
          rescue => err
            $log.warn "Unabled to load XML document with Nokogiri, retrying with REXML" if $log
            self.from_xml(filename, true)
          end
        end

        def self.load(data)
          return self.newDoc() if data.nil?

          begin
            # Create a parser and pass in the string data
            Nokogiri::XML::Document.parse(data, nil, nil, Nokogiri::XML::ParseOptions::RECOVER)
          rescue => err
            self.from_xml(data, false)
          end
        end

        def self.createDoc(rootName, rootAttrs = nil, version = MIQ_XML_VERSION)
          if rootName.nil?
            xml = Nokogiri::XML::Document.new()
          else
            xml = self.load(rootName)
          end
          xml.encoding = 'UTF-8'
          if xml.root
            xml.root.add_attributes({
                "version" => version,
                "created_on" => Time.now.to_i,
                "display_time" => Time.now.getutc.iso8601,
              })
            xml.root.add_attributes(rootAttrs) if rootAttrs
          end
          return xml
        end

        def self.newDoc()
          Nokogiri::XML::Document.new()
        end

        def add_element(name, attrs=nil)
          self.root = newEle = XML::Node.new(name, self)
          self.root.add_attributes(attrs) if attrs
          return newEle
        end

        def find_first(xpath, ns=nil)
          self.at(xpath)
        end

        def find_each(name, &blk)
          self.xpath(name).each {|e| yield(e)}
        end

        def find_match(xpath="//*", nslist = nil)
          self.xpath(xpath)
        end
      end  # class Document
    end  # module XML
  end  # module Nokogiri
rescue LoadError => err
	#$log.info "Unable to load nokogiri [#{err}]" if $log
rescue Gem::Exception => err
  $log.error "Unable to load nokogiri [#{err}]" if $log
end
