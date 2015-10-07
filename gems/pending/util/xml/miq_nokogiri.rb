begin
  # Try to load the nokogiri library bindings.  If it fails then we skip defining the methods below.
  require 'nokogiri'
  require 'util/xml/xml_diff'
  require 'util/xml/xml_patch'

  # Add class methods to nokogiri to have it behave more like REXML for easy replacement
  module Nokogiri
    module XML
      class Attr
        # REXML::Attributes are typically accessed so that it returns the value of an
        # attribute, whereas Nokogiri returns an object with a "value" reader method.
        # Our approach essentially forwards the call to the value.
        def method_missing(*args, &block)
          value.send(*args, &block)
        end
      end

      class Node
        def add_attribute(key, value)
          self[key.to_s] = value.to_s unless value.nil?
        end

        def add_attributes(attr_hash)
          return unless attr_hash
          attr_hash.each_pair { |k, v| add_attribute(k, v) }
        end

        def add_element(element, attrs = nil)
          self << newEle = XML::Node.new(element.to_s, document)
          newEle.add_attributes(attrs)
          newEle
        end

        # Note: In nokogiri the "text" method is an alias for context (and inner_text)
        #       which returns the text for this node plus all it's child nodes.
        # The node_text method only return this nodes text
        def node_text
          children.each do |node|
            if node.node_type == TEXT_NODE
              if node.content && node.content.rstrip.length > 0
                return node.content
              end
            end
          end
          nil
        end

        def text=(string)
          # Find the text node and update it's content.
          children.each do |node|
            if node.node_type == TEXT_NODE
              node.content = string.to_s
              return node.content
            end
          end
          self << XML::Text.new(string.to_s, doc)
        end

        # Last two parms added to duplicate REXML write function
        # they are ignored in this method
        def write(io_handle, indent = -1, _transitive = false, _ie_hack = false)
          options = {:indent => (indent >= 0 ? indent : 0)}

          if String === io_handle
            io_handle.replace(to_xml(options))
          else
            io_handle << to_xml(options)
          end
        end

        def each_element(xpath = "*", &_block)
          find_match(xpath).each { |n| yield n }
        end

        def root
          return nil unless document
          document.root
        end

        def has_elements?
          # Verify there are elements, not just a text node
          each_element { |_e| return true }
          false
        end

        alias_method :doc,      :document
        alias_method :remove!,  :remove

        def find_first(_xpath, _ns = nil)
          at_xpath(*paths)
        end

        def find_each(name, &blk)
          xpath(name, &blk)
        end

        def find_match(xpath = nil, nslist = nil)
          xpath = "*" if xpath.nil?
          self.xpath(xpath, nslist)
        end

        def add_cdata(string)
          self << Nokogiri::XML::CDATA.new(self, string.to_s)
        end
      end  # class Node

      class Document
        # include MiqXmlDiff
        # include MiqXmlPatch

        # MIQ_XML_VERSION = 1.0
        # MIQ_XML_VERSION = 1.1  # Added create_time to root in seconds for easier time conversions
        MIQ_XML_VERSION = 2.0 # Changed sub-xmls, added namespaces

        # def extendXmlDiff; end

        # Last two parms added to duplicate REXML write function
        # they are ignored in this method
        def write(io_handle, indent = -1, _transitive = false, _ie_hack = false)
          options = {:indent => (indent >= 0 ? indent : 0)}

          if String === io_handle
            io_handle.replace(to_xml(options))
          else
            io_handle << to_xml(options)
          end
        end

        def miqEncode
          MIQEncode.encode(to_s)
        end

        def self.loadFile(filename)
          Nokogiri::XML::Document.new(filename)
        rescue => err
          $log.warn "Unable to load XML document with Nokogiri, retrying with REXML" if $log
          from_xml(filename, true)
        end

        def self.load(data)
          return newDoc if data.nil?

          begin
            # Create a parser and pass in the string data
            Nokogiri::XML::Document.parse(data, nil, nil, Nokogiri::XML::ParseOptions::RECOVER)
          rescue => err
            from_xml(data, false)
          end
        end

        def self.createDoc(rootName, rootAttrs = nil, version = MIQ_XML_VERSION)
          if rootName.nil?
            xml = Nokogiri::XML::Document.new
          else
            xml = load(rootName)
          end
          xml.encoding = 'UTF-8'
          if xml.root
            xml.root.add_attributes("version"      => version,
                                    "created_on"   => Time.now.to_i,
                                    "display_time" => Time.now.getutc.iso8601,)
            xml.root.add_attributes(rootAttrs) if rootAttrs
          end
          xml
        end

        def self.newDoc
          Nokogiri::XML::Document.new
        end

        def add_element(name, attrs = nil)
          self.root = newEle = XML::Node.new(name, self)
          root.add_attributes(attrs) if attrs
          newEle
        end

        def find_first(xpath, _ns = nil)
          at(xpath)
        end

        def find_each(name, &_blk)
          xpath(name).each { |e| yield(e) }
        end

        def find_match(xpath = "//*", _nslist = nil)
          self.xpath(xpath)
        end
      end  # class Document
    end  # module XML
  end  # module Nokogiri
rescue LoadError => err
  # $log.info "Unable to load nokogiri [#{err}]" if $log
rescue Gem::Exception => err
  $log.error "Unable to load nokogiri [#{err}]" if $log
end
