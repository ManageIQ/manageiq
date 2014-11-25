module MiqXmlPatch
  unless defined?(XML_DIFF_ADD)
    XML_DIFF_ADD =  1
    XML_DIFF_DEL = -1
    XML_DIFF_FOUND_ATTR = 'miqcomparefound'
  end
  
	def xmlPatch(patch_xml, direction=1)
    raise "Invalid XML Diff document [#{patch_xml.root.name}].  Expected root name [xmlDiff]" unless patch_xml.root.name.to_s == "xmlDiff"

    st = Time.now
    stats = {:deletes=>0, :adds=>0, :updates=>0, :errors=>0}

    # Apply path
		miq_apply_patch(self, patch_xml, direction, stats)
    stats[:_xmlpatchtime_] = Time.now - st

    miq_patch_check(patch_xml, stats, direction)

		return stats
	end

	private  
	def miq_apply_patch(xml, patch, direction, stats)
    nodes = [:deletes, :adds]
		
		# Depending on the direction we are applying the 
		# changes adds and deletes will be switched
		nodes.reverse! if direction < 0

		# Process Deletes first
		miq_patch_elements(xml, patch, nodes[0], XML_DIFF_DEL, stats)

		# Process Adds
		miq_patch_elements(xml, patch, nodes[1], XML_DIFF_ADD, stats)

		# Process Modified elements
    miq_patch_elements(xml, patch, :updates, direction, stats)
	end
	
	def miq_patch_elements(xml, patch, node, direction, stats)
    miq_patch_element_logging(node, direction)
    patch.root.elements[node.to_s].each_element do |e|
			path = e.elements['path'].elements[1]
			data = e.elements['data'].elements[1]

      parent_node = nil

			compare_roots = true if path.nil? and e.elements['path'].attributes['root'] == "true"
			unless compare_roots
        # If the data should already exist add the first data element we are
        # searching for to the search path.
        if node == :updates || direction == XML_DIFF_DEL
          # Set lastElement to the path element in case it has no children
          # and the recursive block below does not execute.
          lastElement = path
          # Find the last element of the search path
          path.each_recursive {|lastE| lastElement = lastE}
          # Add a child element to search for so we ensure we find the 
          # proper node
          lastElement << data.shallow_copy
        end
        
        # If the search path is only one level then we are looking
        # for the root element.  No need to search.
        if path.elements[1].nil?
          compare_roots = true
          ele = xml.root
        else
          ele = miq_find_diff_element(path.elements[1], xml.root)

          if ele.nil?
            stats[:errors] += 1
            miq_patch_logging("Unable to find XML element to update during XML Patching.  Search Path:[#{path}]", :warn)
            next
          end

          parent_node = ele.parent
        end

        if ele.nil?
          stats[:errors] += 1
          miq_patch_logging("XML node not found", :warn)
        end
			end

      miq_patch_process_element(ele, data, path, compare_roots, direction, parent_node, node, xml, stats)

      data_elements = e.attributes['data_count'].to_i
      e.each_element do |de|
        data = de.elements['data']
        data = data.elements[1] if data
        miq_patch_process_element(ele, data, path, compare_roots, direction, parent_node, node, xml, stats) if data
      end unless data_elements.zero?
	  end
	end

  def miq_patch_process_element(ele, data, path, compare_roots, direction, parent_node, node, xml, stats)
      if compare_roots == true
        ele = xml.root
      else
        if node == :updates || direction == XML_DIFF_DEL
          ele = miq_find_diff_element(data.shallow_copy, parent_node)
        end
      end

      if node == :updates
        miq_patch_update_element(ele, data, compare_roots, direction, stats)
			else
				miq_patch_add_element(ele, data, path, stats) if direction > 0
        miq_patch_delete_element(ele, data, path, stats) if direction < 0
		  end
  end

  def miq_patch_update_element(element, data, compare_roots, direction, stats)
    data = data.parent.parent.elements['data_old'].elements[1] if direction < 0
    e2 = compare_roots ? element.root : element

    # Delete all existing attrbutes for this element
    e2.attributes.clear
    # Add new attributes
    e2.add_attributes(data.attributes.to_h)
    # Replace the element text
    e2.text = data.text

    stats[:updates] += 1
  end

  def miq_patch_add_element(element, data, path, stats)
    element.add(data)
    stats[:adds] += 1
  end

  def miq_patch_delete_element(element, data, path, stats)
    if element.nil?
      # We should not get to this point, since the element we want to
      # delete should always exists.  But if we do log a warning.
      stats[:errors] += 1
      miq_patch_logging("Unable to find XML element to delete during XML Patching.  Search Path:[#{path}]", :warn)
    else
      element.remove!
      stats[:deletes] += 1
    end
  end

  def miq_find_diff_element(searchNode, xml)
    data = miq_find_diff_element2(searchNode, xml)
    # If the data is not found miq_find_diff_element2 returns an array
    data = nil if data.is_a?(Array)
    return data
  end
  
 	def miq_find_diff_element2(searchNode, xml)
    # Loop over each element to find matching elements at the current level
		xml.each_element do |dataNode|
      comp_rc = miq_same_element(searchNode, dataNode)
			if comp_rc.zero?
        # If there are no search elements left and we match on
        # and element we found what we are looking for.
        if searchNode.elements[1].nil?
          break(dataNode)
        end
				ret_val = miq_find_diff_element2(searchNode.elements[1], dataNode)
        if ret_val && !ret_val.is_a?(Array)
          break(ret_val)
        end
			end
		end		
	end

  def miq_patch_element_logging(node, direction)
    patch_mode = direction >= XML_DIFF_ADD ? "adds" : "deletes"
    patch_mode = "udpates" if node == :updates
    miq_patch_logging("Processing xml patches for [#{patch_mode}] from node [#{node}].  Direction flag:[#{direction}]")
  end

  def miq_patch_logging(message, level=:debug)
    return $log.send(level, message) if $log
    #puts "#{level}: #{message}"
  end

  def miq_patch_check(patch_xml, stats, direction)
    expected = patch_xml.root.attributes.to_h
    expected[:adds], expected[:deletes] = expected[:deletes], expected[:adds] if direction < 0

    miq_patch_logging("Errors detected during Xml Patching for document:[#{self.root.name}].  Error count:[#{stats[:errors]}]", :warn) unless stats[:errors].zero?
    miq_patch_logging("XML patching results for document:[#{self.root.name}]: Adds-Applied:[#{stats[:adds]}] Expected:[#{expected[:adds]}] -- Deletes-Applied:[#{stats[:deletes]}] Expected:[#{expected[:deletes]}] -- Updates-Applied:[#{stats[:updates]}] Expected:[#{expected[:updates]}]  Errors:[#{stats[:errors]}]")
  end
end