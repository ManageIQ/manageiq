require 'digest/md5'

module MiqXmlDiff
  unless defined?(XML_DIFF_ADD)
    XML_DIFF_ADD =  1
    XML_DIFF_DEL = -1
    XML_DIFF_FOUND_ATTR = 'miqcomparefound'
  end

	def xmlDiff (xml, stats={})
    st = Time.now
		stats[:deletes] = stats[:adds] = stats[:updates] = 0
		delta = self.class.createDoc("<xmlDiff><adds/><deletes/><updates/></xmlDiff>")
    diff_elements = {}
    delta.root.each_element {|e| diff_elements[e.name.to_sym] = e}
		miq_compare_roots(self, xml, delta, diff_elements, stats)
		delta.root.add_attributes(:adds=>stats[:adds], :deletes=>stats[:deletes], :updates=>stats[:updates])
    timestamp = xml.root.attributes[:_timestamp_].nil? ? xml.root.attributes[:created_on] : xml.root.attributes[:_timestamp_]
    stats[:_xmldifftime_] = Time.now - st
		delta.root.add_attributes(:created_on=>timestamp, :display_time=>xml.root.attributes[:display_time])
    miq_compare_logging("XML differencing results [#{stats.inspect}].  Document:[#{xml.root.name}]")
    return delta
	end
			
  private
	def miq_compare_roots(node1, xml2, delta, diff_elements, stats)
		raise "XML Root names do not match.  Node1:<#{node1.root.name}>  Node2:<#{xml2.root.name}>" unless node1.root.name == xml2.root.name
		if miq_compare_attributes(node1.root, xml2.root) == false
			# *** MODIFIED root element detected
			miq_record_change([node1.root, xml2.root], delta, diff_elements, stats)
		end
		miq_compare_elements(node1.root, xml2.root, delta, diff_elements, stats)
	end
	
	def miq_compare_elements(node1, node2, delta, diff_elements, stats)
		node1.each_element do |e1|
      e2 = miq_find_element(e1, node2)
			if e2
				if miq_compare_attributes(e1, e2) == false
					# *** MODIFIED element detected
					miq_record_change([e1, e2], delta, diff_elements, stats)
				end
				
				miq_compare_elements(e1, e2, delta, diff_elements, stats)
				# If this element matches we can do one of two things:
				#   1) If it does not have any child elements - delete it
				#   2) If it does have any child elements - mark it as having been visited
				if e2.has_elements?
					e2.attributes[XML_DIFF_FOUND_ATTR] = true
				else
					e2.remove!
				end
			else
				# *** NEW element detected
				miq_record_change([e1, nil], delta, diff_elements, stats)
			end
		end
		
		# Search for deletes
		if node2
			node2.each_element {|e2|
				# *** DELETED element detected
				miq_record_change([nil, e2], delta, diff_elements, stats) if e2.attributes[XML_DIFF_FOUND_ATTR].nil?
			}
		end
	end
	
	def miq_record_change(node, delta, diff_elements, stats)
		srcPath = node[0].nil? ? node[1] : node[0]
		
		if node[1].nil?
			action = :adds
		elsif node[0].nil?
			action = :deletes
			node.reverse!
		else
			action = :updates
      [0,1].each {|i| e = node[i].shallow_copy; e.text = node[i].text; node[i] = e}
   	end
		
		miq_updateStatCount(action, stats)
		
		# Add items to delta xml file
    path = srcPath.get_path
		path_md5 = Digest::MD5.hexdigest(action.to_s + (path.nil? ? "root=>true" : path.to_s))

    # Check if we have already added an item node for this action and path, if so
    # just add the data node(s) to it.  Otherwise create a new item node.
    p = diff_elements[path_md5]
    if p.nil?
      p = diff_elements[action].add_element(:item)
      # Comment out next line to disable new style xml diff output
      diff_elements[path_md5] = p
      path.nil? ? p.add_element(:path, {:root=>true}) : p.add_element(:path) << path
    else
      data_index = p.attributes['data_count'].to_i + 1
      p.attributes['data_count'] = data_index
      p = p.add_element("d#{data_index}")
    end

		unless node[1]
			ele_idx = miq_compare_get_element_index(node[0])
			p.add_element(:data, {:index=>ele_idx}) << node[0]
		else
			p.add_element(:data) << node[0]
			p.add_element(:data_old) << node[1]
		end
	end
	
	def miq_compare_get_element_index(ele)
		p = ele.parent
		#n = p.elements.index(ele)
		return 0
	end
	
	def miq_compare_attributes(e1, e2)
		# If the attribute count does not match, they can't be equal
    return false if e1.attributes.length != e2.attributes.length
		
		# Next check the element text (use to_s to convert nil to "")
    return false if e1.text.to_s.rstrip != e2.text.to_s.rstrip

		# Finally make sure all the attributes match
		e1.attributes.each_attrib do |k, v|
      next if k.to_sym == :updated_on
      return false if v != e2.attributes[k]
    end
		true
	end
	
	def miq_updateStatCount(action, stats)
    stats[action.to_sym] += 1
	end
	
	def miq_find_element(e, node)
		return nil unless node
		found = nil
		node.each_element {|e2| 
			found = e2 if miq_same_element(e, e2) == 0
			break if found
		}
		return found
	end
	
	def miq_same_element(e1, e2)
		# Return non-zero so we know the attributes do not match
		return 1 if e1.name != e2.name

		# Compare each attribute and return non-zero if we find attributes that do not match.
		# If an attribute does not exist it will evaluate to nil.  If it is missing from both
		# sides it will be considered a match.
    keys = Symbol == e1.key_type ? [:keyname, :name, :type, :id, :guid] : %w(keyname name type id guid)
    keys.each {|a| return 1 if e1.attributes[a] != e2.attributes[a]}
      
		# Main attributes match
		return 0
	end

  def  miq_compare_logging(message, level=:debug)
    $log.send(level, message) if $log
    #puts "#{level}: #{message}"
  end
end