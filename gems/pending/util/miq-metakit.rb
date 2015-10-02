require 'mk4rb'

module Metakit
  class Property
  end

  class View
    # Make Active Record-like names
    alias_method(:count, :get_size)
    alias_method(:length, :get_size)

    attr_accessor :table_name

    def attributes
      props = []
      0.upto(num_properties - 1) { |i| props << nth_property(i) }
      props
    end

    def attribute_names
      props = []
      x = attributes.each { |p| props << p.name }
      props
    end

    def each
      0.upto(get_size - 1) { |row| yield self[row] }
    end

    def to_xml
      xml = MiqXml.createDoc("<view name='#{table_name}'><attributes/><rows/></view>")

      xmlNode = xml.find_first("//view/attributes")
      props = attribute_names
      props.each { |prop| xmlNode.add_element("attribute", "name" => prop) }

      xmlNode = xml.find_first("//view/rows")
      each do |row|
        row_attributes = props.inject({}) do |row_attributes, prop|
          row_attributes[prop] = row[prop]
          row_attributes
        end

        xmlNode.add_element("row", row_attributes)
      end

      xml
    end

    def find_by_hash(value)
      row_to_find = create_row_from_hash(value)

      # Find the row in the view
      self[find(row_to_find)]
    end

    def find_range_by_hash(from_value = nil, to_value = nil)
      return self if count == 0

      sorted = sort

      row_from = (from_value.nil? ? sorted[0] : create_row_from_hash(from_value))
      row_to = (to_value.nil? ? sorted[sorted.count - 1] : create_row_from_hash(to_value))

      sorted.select_range(row_from, row_to)
    end

    def build(value)
      retVal = nil
      if value.kind_of?(Array)
        retVal = []
        value.each { |h| retVal << build_from_hash(h) }
      elsif value.kind_of?(Hash)
        retVal = build_from_hash(value)
      end

      retVal
    end

    def build_from_hash(value)
      newRow = create_row_from_hash(value)

      # Add the row to the view
      self[add(newRow)]
    end

    def create_row_from_hash(value)
      newRow = Metakit::Row.new

      # Set the data for each key/value pair in the hash
      value.each_pair do |k, v|
        x = find_prop_index_by_name(k.to_s)
        if x > -1
          y = nth_property(x)

          # Check that the value type is valid for the column type
          # For example: This will call "to_i" on a Time object to store in seconds if the
          # property is an Int, or to_s to store Time as a string if the property is a string.
          # The one big difference is "Binary" data which should be passed in as a string and
          # converted into the "Metakit::Bytes" object.
          v = case y.class.to_s
              when "Metakit::StringProp"
                v.to_s
              when "Metakit::LongProp", "Metakit::IntProp"
                v.to_i
              when "Metakit::FloatProp", "Metakit::DoubleProp"
                v.to_f
              when "Metakit::BytesProp"
                Metakit::Bytes.new(v, v.length)
              else
                v
              end

          y.set(newRow, v)
        else
          $log.warn "Property [#{k}] not found in metakit table"
        end
      end

      newRow
    end
  end

  class RowRef
    def getAttribute(index)
      # Convert index from a name to a property index number
      index = container.find_prop_index_by_name(index.to_s) unless index.kind_of? Integer
      return nil if index.nil?
      raise "index (#{index}) must be >= 0" if index < 0
      container.nth_property(index)
    end

    def [](index)
      attr = getAttribute(index)
      return nil if attr.nil?

      # Retrieve the property data for this row
      attr.get(self)
    end

    def []=(index, value)
      attr = getAttribute(index)
      return nil if attr.nil?

      # Set the property data for this row
      attr.set(self, value)
    end
  end

  class Storage
    # Make Active Record-like names
    alias_method(:save, :commit)
    alias_method(:save!, :commit)

    alias_method :view_old, :view

    # Redefined view to store the name of the view
    def view(name)
      new_view = view_old(name)
      new_view.table_name = name
      new_view
    end
  end
end
