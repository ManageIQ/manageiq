$:.push("#{File.dirname(__FILE__)}/../../util")

require 'miq-xml'

module XmlMsHyperVConfig
#  def logical_id(element)
#    add_item('displayName', element.text)
#  end

  def properties(element)
    add_item('displayName', element.elements['name'].text)
  end

  def memory(element)
    add_item("memsize", element.elements[1].elements[1].text)
  end

  def processors(element)
    add_item("numvcpu", element.elements['count'].text)
  end

  def global_id(element)
    add_item('ems.uid', element.text)
  end

  def controller0(element)
    element.each_element do |drive|
      next if drive.name[0,5] != 'drive'
      if drive.elements['type'].text == 'VHD'
        add_item("ide0:#{drive.name.reverse.to_i}.fileName", drive.elements['pathname'].text)
      end
    end
  end

	def parse_create_time(filename)
		name = File.basename(filename, ".*").split("_")[-1]
		Time.parse("#{name[10..13]}-#{name[6..7]}-#{name[8..9]}T#{name[0..1]}:#{name[2..3]}:#{name[4..5]}").utc
	end

  def vendor
    return "microsoft"
  end
end
