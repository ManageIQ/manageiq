###################################
#
# EVM Automate Method: Inspect_me
#
# Notes: Log all objects stored in the $evm.root hash.
#        Then log the attributes, associations, tags and
#        virtual_columns for each automate service model.
#
###################################

def dump_root
  $evm.log("info", "Root:<$evm.root> Attributes - Begin")
  $evm.root.attributes.sort.each { |k, v| $evm.log("info", "  Attribute - #{k}: #{v}") }
  $evm.log("info", "Root:<$evm.root> Attributes - End")
  $evm.log("info", "")
end

def dump_ar_objects
  $evm.root.attributes.sort.each do |k, v|
    dump_ar_object(k, v) if v.kind_of?(DRb::DRbObject) && v.try(:object_class)
  end
end

def dump_ar_object(key, object)
  $evm.log("info", "key:<#{key}>  object:<#{object}>")
  dump_attributes(object)
  dump_associations(object)
  dump_tags(object)
  dump_virtual_columns(object)
end

def dump_attributes(object)
  $evm.log("info", "  Begin Attributes [object.attributes]")
  object.attributes.sort.each { |k, v| $evm.log("info", "    #{k} = #{v.inspect}") }
  $evm.log("info", "  End Attributes [object.attributes]")
  $evm.log("info", "")
end

def dump_associations(object)
  $evm.log("info", "  Begin Associations [object.associations]")
  object.associations.sort.each { |assc| $evm.log("info", "    Associations - #{assc}") }
  $evm.log("info", "  End Associations [object.associations]")
  $evm.log("info", "")
end

def dump_tags(object)
  return if object.tags.nil?

  $evm.log("info", "  Begin Tags [object.tags]")
  object.tags.sort.each do |tag_element|
    tag_text = tag_element.split('/')
    $evm.log("info", "    Category:<#{tag_text.first.inspect}> Tag:<#{tag_text.last.inspect}>")
  end
  $evm.log("info", "  End Tags [object.tags]")
  $evm.log("info", "")
end

def dump_virtual_columns(object)
  $evm.log("info", "  Begin Virtual Columns [object.virtual_column_names]")
  object.virtual_column_names.sort.each { |vcn| $evm.log("info", "    Virtual Columns - #{vcn}: #{object.send(vcn).inspect}") }
  $evm.log("info", "  End Virtual Columns [object.virtual_column_names]")
  $evm.log("info", "")
end

dump_root
dump_ar_objects
