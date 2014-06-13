require 'miq-xml'
require 'xml_hash'
require 'enumerator'

class XmlFind
  def self.decode(data, format)
    method = data.kind_of?(Hash) ? :findNamedElement_hash : :findNamedElement
    nh = Hash.new
    format.each_slice(2) {|k,v| nh[v] = self.send(method, k, data)}
    return nh
  end
  
  def self.findNamedElement(findStr, ele)
    ele.each_element do |e|
      if e.name == "value" && e.attributes['name'].downcase == findStr.downcase then
        return e.text
      end   #if
      if e.has_elements? then
        subText = findNamedElement(findStr, e)
        return subText unless subText.nil?
      end
    end
    return nil
  end
  
  def self.findNamedElement_hash(findStr, ele)
    ele.each_element do |e|
      if e.name == :value && e.attributes[:name].downcase == findStr.downcase then
        return e.text
      end   #if
      if e.has_elements? then
        subText = findNamedElement_hash(findStr, e)
        return subText unless subText.nil?
      end
    end
    return nil
  end  
  
  def self.findElement(path, element)
    path_fix_up = path.tr("\\", "/").split("/")
    return XmlHash::XmhHelpers.findElementInt(path_fix_up, element) if element.kind_of?(Hash)
    findElementInt(path_fix_up, element)
  end
  
  def self.findElementInt(paths, ele)
    if paths.length > 0 then
      found = false
      searchStr = paths[0]
      paths = paths[1..paths.length]
      #puts "Search String: #{searchStr}"
      ele.each_element do |e|
        #puts "Current String: [#{e.name.downcase}]"
        if e.name.downcase == searchStr.downcase || (e.attributes['keyname'] != nil && e.attributes['keyname'].downcase == searchStr.downcase) || (e.attributes['name'] != nil && e.attributes['name'].downcase == searchStr.downcase) then
          #puts "String Found: [#{e.name}]"
          return findElementInt(paths, e)
        end # if
      end # do      
    else
      return ele
    end
		return nil
  end
end

class XmlHelpers
  def self.stringify_keys(h)
    return nil if h.nil?
    h.inject({}) {|options, (key, value)| options[key.to_s] = value; options}
  end
end

class Xml2tags
  def self.walk(node, parents="")
    tags = Array.new

    sep = "/"
    case node.name
    when "value"
      node.each_child {|e|
        if e.respond_to?("value")
          if parents.split(":").last != node.attributes["name"]
            tag = parents + sep + node.attributes["name"] + sep + e.value
          else
            tag = parents + sep + e.value
          end
          tags << normalize(tag)
          #puts "Tag <value> = #{tag}"
        else break
        end
      }
    when"key"
      if parents.split(sep).last != node.attributes["keyname"]
        tag = parents + sep + node.attributes["keyname"]
        tags << normalize(tag)
        #puts "Tag <key> = #{tag}"
        parents = parents + sep + node.attributes["keyname"] 
      end
    when "miq"
      #Don't include in tag
    else
      parents = parents + sep + node.name if parents.split(sep).last != node.name
      node.attributes.each {|k, v|
        tag = parents + sep + k + sep + v
        tags << normalize(tag)
        #puts "Tag <default> = #{tag}"
      }
    end

    node.each_child {|e| tags = tags + walk(e, parents) if MiqXml.isXmlElement?(e)}
    return tags
  end

  def self.normalize(tag)
    return tag.gsub(/ /,'_')
  end
end

class Xml2Array
  def self.element2hash(doc, path)
    obj = Hash.new
    doc.find_each(path + "/*") { |element|
      text = element.text
      text = "" if text.nil?
      if text.strip != ""
        obj[element.name] = element.text
      else 
        cobj = element2hash(doc, path + "/" + element.name)
        obj[element.name] = cobj if !cobj.nil?
      end
    }
    return obj.symbolize_keys
  end

  def self.getNodeDetails(doc, path)
    result = Array.new
    doc.elements.to_a("//" + path + "/*").each {|node|
      path ="//" + node.name
      result.push(element2hash(doc, path))
    }
    return result
  end
end
