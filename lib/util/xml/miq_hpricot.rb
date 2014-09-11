begin
  # Try to load the hpricot library bindings.  If it fails then we skip defining the methods below.
  require 'rubygems'
  require 'hpricot'

  module Hpricot
    def self.loadFile(filename)
      begin
        f = nil
        f = File.open(filename,"r")
        Hpricot.XML(f)
      ensure
        f.close if f
      end
    end

    def self.load(data)
      Hpricot.XML(data)
    end

    class Doc
      def each_element(xpath="*", &block)
        self.root.each_element(xpath="*", &block)
      end

      # Last three parms to added to duplicate REXML write function
      # they are ignored in this method
      def write(io_handle, indent=-1, transitive=false, ie_hack=false)
        io_handle.write(self.to_s)
      end
    end

    class Document
      def self.loadFile(filename)
        Hpricot.loadFile(filename)
      end
    end

    class Elem
      def each_element(xpath="*", &block)
        self.children.each do |c|
          if c.kind_of?(Elem)
            yield(c)
          end
        end
      end

      def text
        self.children[0].content if self.children[0]
      end

      def text=(value)
        self.children[0].content = value
      end
    end

    class Attr
      def to_h
        self
      end
    end
  end
rescue LoadError => err
	#$log.info "Unable to load libxml [#{err}]" if $log
end
