module XmlBaseParserTests

  def default_test_xml()
    xml_string = <<-EOL
      <?xml version='1.0' encoding='UTF-8'?>
      <rows>
        <head>
          <column width='10' type='link' sort='str'>Name</column>
          <column width='10' type='ro' sort='str'>Host Name</column>
          <column width='10' type='ro' sort='str'>IP Address</column>
          <column width='10' type='ro' sort='str'>VMM Vendor</column>
          <column width='10' type='ro' sort='str'>VMM Version</column>
          <column width='10' type='ro' sort='str'>VMM Product</column>
          <column width='10' type='ro' sort='str'>Registered On</column>
          <column width='10' type='ro' sort='str'>SmartState Heartbeat</column>
          <column width='10' type='ro' sort='str'>SmartState Version</column>
          <column width='10' type='ro' sort='str'>WS Port</column>
          <settings>
            <colwidth>%</colwidth>
          </settings>
        </head>
        <row id='8'>
          <cell>esxdev001.localdomain^/host/show/8^_self</cell>
          <cell>esxdev001.localdomain</cell>
          <cell>192.168.177.49</cell>
          <cell>VMware</cell>
          <cell>3.0.2</cell>
          <cell>ESX Server</cell>
          <cell>Thu Jun 05 16:46:35 UTC 2008</cell>
          <cell></cell>
          <cell></cell>
          <cell></cell>
        </row>
        <row id='7'>
          <cell>esxdev002.localdomain^/host/show/7^_self</cell>
          <cell>esxdev002.localdomain</cell>
          <cell>192.168.177.50</cell>
          <cell>VMware</cell>
          <cell>3.0.2</cell>
          <cell>ESX Server</cell>
          <cell>Thu Jun 05 16:46:34 UTC 2008</cell>
          <cell></cell>
          <cell></cell>
          <cell></cell>
        </row>
        <row id='6'>
          <cell>JFREY-LAPTOP.manageiq.com^/host/show/6^_self</cell>
          <cell>JFREY-LAPTOP.manageiq.com</cell>
          <cell>192.168.252.143</cell>
          <cell>Unknown</cell>
          <cell></cell>
          <cell></cell>
          <cell>Wed Apr 23 19:38:44 UTC 2008</cell>
          <cell></cell>
          <cell></cell>
          <cell></cell>
        </row>
        <row id='4'>
          <cell>luke.manageiq.com^/host/show/4^_self</cell>
          <cell>luke.manageiq.com</cell>
          <cell>192.168.252.32</cell>
          <cell>VMware</cell>
          <cell>3.0.1</cell>
          <cell>ESX Server</cell>
          <cell>Tue Apr 22 15:59:19 UTC 2008</cell>
          <cell></cell>
          <cell></cell>
          <cell></cell>
        </row>
        <row id='5'>
          <cell>yoda.manageiq.com^/host/show/5^_self</cell>
          <cell>yoda.manageiq.com</cell>
          <cell>192.168.252.2</cell>
          <cell>VMware</cell>
          <cell>3.0.1</cell>
          <cell>ESX Server</cell>
          <cell>Tue Apr 22 15:59:20 UTC 2008</cell>
          <cell></cell>
          <cell></cell>
          <cell></cell>
        </row>
      </rows>
    EOL
    xml_string.strip!
  end

  def test_create_document
    xml = @xml
    assert_kind_of(@xml_klass::Document, xml)

    #    @xml_klass.load(@xml_string)
    #    assert_kind_of(@xml_klass::Document, xml)
  end

  def test_each_element()
    xml = @xml

    count = 0
    xml.each_element {|e| count += 1}
    assert_equal(1, count)

    # Test each method with and without xpaths
    count = 0
    xml.root.each_element {|e| count += 1}
    assert_equal(6, count)

    count = 0
    xml.root.each_element("head") {|e| count += 1}
    assert_equal(1, count)

    count = 0
    xml.root.each_element("row") {|e| count += 1}
    assert_equal(5, count)

    count = 0
    xml.root.elements.each {|e| count += 1}
    assert_equal(6, count)
  end

  def test_has_children
    node = @xml.root
    assert_equal('rows', node.name.to_s)
    assert_equal(true, node.has_elements?)

    node = node.elements[1]
    assert_equal('head', node.name.to_s)
    assert_equal(true, node.has_elements?)

    node = node.elements[1]
    assert_equal('column', node.name.to_s)
    assert_equal(false, node.has_elements?)
  end

  # Moving xml nodes between documents is a feature required for differencing
  def test_move_node()
    xml_full = MiqXml.load(@xml_string, @xml_klass)
    xml_part = MiqXml.load("<root/>", @xml_klass)
    xml_part.root << xml_full.root.elements[2]

    count = 0
    full_ids = []
    xml_full.root.each_element {|e| count += 1; full_ids << e.attributes["id"]}
    assert_equal(5, count)

    count = 0
    xml_part.root.each_element {|e| count += 1}
    assert_equal(1, count)

    assert_equal("8", xml_part.root.elements[1].attributes["id"])
    assert(!full_ids.include?("8"))

    # Re-assign root document value
    doc = MiqXml.load(@xml_string, @xml_klass)
    doc.root = doc.root.elements[1].elements[1]

    assert_equal("column", doc.root.name.to_s)
    assert_equal("link", doc.root.attributes[:type])
  end

  def test_doc_root_reassignment
    # Re-assign root document value
    doc = MiqXml.load(@xml_string, @xml_klass)
    doc.root = doc.root.elements[1].elements[1]
    GC.start  # Required by libxml to avoid core dump

    assert_equal("column", doc.root.name.to_s)
    assert_equal("link", doc.root.attributes["type"].to_s)
  end

  def test_root_text
    node = @xml.root
    assert_equal("", node.text.to_s.rstrip)
    node.text = "Hello World"
    assert_equal("Hello World", node.text.to_s.rstrip)

    # Make sure adding text does not destroy child elements
    assert_equal(true, node.has_elements?)
    count = 0
    @xml.root.each_element {|e| count += 1}
    assert_equal(6, count)
  end

  def test_diff()
    xml = MiqXml.newDoc(@xml_klass)
    assert_respond_to(xml, :xmlDiff)
    assert_respond_to(xml, :xmlPatch)

    stats = {}

    xml_old = MiqXml.load(@xml_string, @xml_klass)
    xml_new = MiqXml.load(@xml_string, @xml_klass)
    xml_diff = xml_new.xmlDiff(xml_old, stats)
    assert_equal(0, stats[:adds])
    assert_equal(0, stats[:deletes])
    assert_equal(0, stats[:updates])

    # Reload document and simulate a deleted node
    xml_old = MiqXml.load(@xml_string, @xml_klass)
    xml_new = MiqXml.load(@xml_string, @xml_klass)
    node = xml_new.root.elements[3]
    assert_equal("7", node.attributes[:id])
    node.remove!
    xml_diff = xml_new.xmlDiff(xml_old, stats)

    assert_equal(0, stats[:adds])
    assert_equal(1, stats[:deletes])
    assert_equal(0, stats[:updates])

    # Reload document and simulate an added node
    xml_old = MiqXml.load(@xml_string, @xml_klass)
    xml_new = MiqXml.load(@xml_string, @xml_klass)
    node = xml_new.root.add_element("added_test_element", {:id=>10})
    xml_diff = xml_new.xmlDiff(xml_old, stats)
    assert_equal(1, stats[:adds])
    assert_equal(0, stats[:deletes])
    assert_equal(0, stats[:updates])

    # Reload document and simulate an update to a node with a changed attribute value
    xml_old = MiqXml.load(@xml_string, @xml_klass)
    xml_new = MiqXml.load(@xml_string, @xml_klass)
    node = xml_new.root.elements[1].elements[1]
    assert_equal("link", node.attributes[:type])
    node.add_attribute(:width, "11")
    xml_diff = xml_new.xmlDiff(xml_old, stats)
    assert_equal(0, stats[:adds])
    assert_equal(0, stats[:deletes])
    assert_equal(1, stats[:updates])

    # Reload document and simulate an update to a node with a new attribute
    xml_old = MiqXml.load(@xml_string, @xml_klass)
    xml_new = MiqXml.load(@xml_string, @xml_klass)
    node = xml_new.root.elements[1].elements[1]
    assert_equal("link", node.attributes[:type])
    node.add_attribute(:test_attr, "hello there")
    xml_diff = xml_new.xmlDiff(xml_old, stats)
    assert_equal(0, stats[:adds])
    assert_equal(0, stats[:deletes])
    assert_equal(1, stats[:updates])

    # Reload document and simulate an update to a node with a deleted attribute
    xml_old = MiqXml.load(@xml_string, @xml_klass)
    xml_new = MiqXml.load(@xml_string, @xml_klass)
    node = xml_new.root.elements[1].elements[1]
    assert_equal("link", node.attributes[:type])
    node.attributes.delete(:sort)
    node.attributes.delete("sort")
    xml_diff = xml_new.xmlDiff(xml_old, stats)
    assert_equal(0, stats[:adds])
    assert_equal(0, stats[:deletes])
    assert_equal(1, stats[:updates])
  end

  def test_patch()
    assert_respond_to(@xml, :xmlDiff)
    assert_respond_to(@xml, :xmlPatch)

    stats = {}

    # Reload document and simulate a deleted node
    xml_old = MiqXml.load(@xml_string, @xml_klass)
    xml_new = MiqXml.load(@xml_string, @xml_klass)
    node = xml_new.root.elements[3]
    assert_equal("7", node.attributes[:id])
    node.remove!
    xml_diff = xml_new.xmlDiff(xml_old, stats)
    assert_equal(0, stats[:adds])
    assert_equal(1, stats[:deletes])
    assert_equal(0, stats[:updates])

    xml_old = MiqXml.load(@xml_string, @xml_klass)
    xml_new = MiqXml.load(@xml_string, @xml_klass)
    node = xml_new.root.elements[3]
    assert_equal("7", node.attributes[:id])
    node.remove!
    patch_ret = xml_old.xmlPatch(xml_diff)
    assert_equal(0, patch_ret[:errors])

    xml_diff = xml_new.xmlDiff(xml_old, stats)
    assert_equal(0, stats[:adds])
    assert_equal(0, stats[:deletes])
    assert_equal(0, stats[:updates])

    # Reload document and simulate an added node
    xml_old = MiqXml.load(@xml_string, @xml_klass)
    xml_new = MiqXml.load(@xml_string, @xml_klass)
    node = xml_new.root.elements[3]
    assert_equal("7", node.attributes[:id])
    node.add_element("new_test_node", {"attr1"=>"one"})
    xml_diff = xml_new.xmlDiff(xml_old, stats)
    assert_equal(1, stats[:adds])
    assert_equal(0, stats[:deletes])
    assert_equal(0, stats[:updates])

    xml_old = MiqXml.load(@xml_string, @xml_klass)
    xml_new = MiqXml.load(@xml_string, @xml_klass)
    node = xml_new.root.elements[3]
    assert_equal("7", node.attributes[:id])
    node.add_element("new_test_node", {"attr1"=>"one"})
    patch_ret = xml_old.xmlPatch(xml_diff)
    assert_equal(0, patch_ret[:errors])

    xml_diff = xml_new.xmlDiff(xml_old, stats)
    assert_equal(0, stats[:adds])
    assert_equal(0, stats[:deletes])
    assert_equal(0, stats[:updates])

    # Reload document and simulate an updated node
    xml_old = MiqXml.load(@xml_string, @xml_klass)
    xml_new = MiqXml.load(@xml_string, @xml_klass)
    node = xml_new.root.elements[3]
    assert_equal("7", node.attributes[:id])
    node.add_attribute("new_test_node", {"attr1"=>"one"})
    xml_diff = xml_new.xmlDiff(xml_old, stats)
    assert_equal(0, stats[:adds])
    assert_equal(0, stats[:deletes])
    assert_equal(1, stats[:updates])

    xml_old = MiqXml.load(@xml_string, @xml_klass)
    xml_new = MiqXml.load(@xml_string, @xml_klass)
    node = xml_old.root.elements[3]
    assert_equal("7", node.attributes[:id])
    node.add_attribute("new_test_node", {"attr1"=>"one"})
    patch_ret = xml_old.xmlPatch(xml_diff, -1)
    assert_equal(0, patch_ret[:errors])

    xml_diff = xml_new.xmlDiff(xml_old, stats)
    assert_equal(0, stats[:adds])
    assert_equal(0, stats[:deletes])
    assert_equal(0, stats[:updates])
  end

#  def test_load_file
#    # TODO: Load file test
#  end

  def test_root_pointer
    xml = MiqXml.load(@xml_string, @xml_klass)
    node = xml.elements[1].elements[1].elements[11].elements[1]
    while node
      if node.parent
        if @xml_klass == Nokogiri::XML
          assert_kind_of(@xml_klass::Node, node)
        else
          assert_kind_of(@xml_klass::Element, node)
        end
      else
        assert_kind_of(@xml_klass::Document, node)
      end
      node = node.parent
    end
  end

  def test_attribute()
    xml = @xml
    assert_kind_of(@xml_klass::Document, xml)

    node = xml.find_first("//column")
    assert_equal(true, node.attributes.has_key?("type"))

    attrs = xml.root.attributes.to_h
    assert_kind_of(Hash, attrs)
    assert_equal(0, attrs.length)

    attrs = node.attributes.to_h
    assert_kind_of(Hash, attrs)
    assert_equal(3, attrs.length)

    count = 0
    node.attributes.each_attrib do |k,v|
      assert_not_nil(k)
      assert_instance_of(String, k)
      assert_not_nil(v)
      assert_instance_of(String, v)
      count += 1
    end
    assert_equal(3, count)

    count = 0
    node.attributes.to_h.each do|k,v|
      assert_not_nil(k)
      assert_instance_of(Symbol, k)
      assert_not_nil(v)
      count += 1
    end
    assert_equal(3, count)

    node.attributes.to_h.each do|k,v|
      assert_instance_of(Symbol, k)
    end

    node.attributes.to_h(true).each do|k,v|
      assert_instance_of(Symbol, k)
    end

    node.attributes.to_h(false).each do|k,v|
      assert_instance_of(String, k)
    end

    e1 = e2 = node
    e1.attributes.each_pair do |k, v|
      assert_equal(false, v.to_s != e2.attributes[k])
    end

    e1.attributes.each_key do |k|
      assert_instance_of(String, k)
    end
  end

  def test_missing_attribute
    # Validate that nil is return for attributes that do not exist
    e = @xml.root.elements[2]
    assert_equal(e.attributes['id'], '8')
    assert_nil(e.attributes['none'])
    puts
  end

  def test_get_element()
    xml = @xml
    node = xml.elements[1]
    assert_equal("rows", node.name.to_s)

    node = xml.elements[1].elements[1]
    assert_equal("head", node.name.to_s)

    node = xml.elements[1].elements[1].elements[11].elements[1]
    assert_equal("colwidth", node.name.to_s)

    # Test getting individual sub-elements
    node = xml.root.elements[1]
    assert_nil(node.attributes["id"])

    node = xml.root.elements[1]
    assert_nil(node.attributes["id"])

    node = xml.root.elements[3]
    assert_equal("7", node.attributes["id"].to_s)

    node = xml.root.elements[6]
    assert_equal("5", node.attributes["id"].to_s)

    assert_raise(RuntimeError) {xml.root.elements[0]}

    assert_nil(xml.root.elements[7])

    head = xml.root.elements[1]
    assert_equal("head", head.name.to_s)

    count = 0
    head.each_element {|e| count += 1}
    assert_equal(11, count)

    count = 0
    head.each_element("settings") {|e| count += 1}
    assert_equal(1, count)

    node = xml.root.elements[3]
    node2 = xml.root.elements[4]
    copied_node = node.elements << node2
    assert_equal("7", copied_node.parent.attributes["id"].to_s)

    # Test that node (id=6) is now inside of node id=7
    node = xml.root.elements[3]
    assert_equal("7", node.attributes["id"].to_s)
    node2 = node.elements[11]
    assert_equal("6", node2.attributes["id"].to_s)
  end

  def test_create_new_doc()
    xml_new = MiqXml.newDoc(@xml_klass)
    assert_nil(xml_new.root)
    xml_new.add_element('root')
    assert_not_nil(xml_new.root)
    assert_equal("root", xml_new.root.name.to_s)

    new_node = xml_new.root.add_element("node1", "enabled"=>true, "disabled"=>false, "nothing"=>nil)

    assert_equal(true, MiqXml.isXmlElement?(new_node))
    assert_equal(false, MiqXml.isXmlElement?(nil))

    attrs = new_node.attributes
    assert_equal("true", attrs["enabled"].to_s)
    assert_equal("false", attrs["disabled"].to_s)
    assert_nil(attrs["nothing"])
    new_node.add_attributes("nothing"=>"something")
    assert_equal("something", new_node.attributes["nothing"].to_s)

    assert_kind_of(@xml_klass::Document, xml_new.document)
    assert_kind_of(@xml_klass::Document, xml_new.doc)
    assert_not_equal(@xml_klass::Document, xml_new.root.class)
    assert_kind_of(@xml_klass::Document, xml_new.root.doc)
    assert_equal(xml_new.document, xml_new.doc)
    assert_kind_of(@xml_klass::Document, xml_new.root.doc)
    assert_not_equal(@xml_klass::Document, xml_new.root.root.class)

    # Create an empty document with the utf-8 encoding
    # During assert allow for single quotes and new line char.
    xml_new = MiqXml.createDoc(nil, nil, nil, @xml_klass)
    assert_equal("<?xml version='1.0' encoding='UTF-8'?>", xml_new.to_xml.to_s.gsub("\"", "'").chomp)
  end

  def test_create_new_node()
    node = MiqXml.newNode("scan_item", @xml_klass)
    assert_equal("<scan_item/>", node.to_xml.to_s)
    node = MiqXml.newNode(nil, @xml_klass)
    assert_equal("</>", node.to_xml.to_s)
  end

  def test_xml_encoding()
    xml_new = @xml
    encoded_xml = xml_new.miqEncode()
    assert_instance_of(String, encoded_xml)
    xml_unencoded = MiqXml.decode(encoded_xml, @xml_klass)
    assert_equal(xml_new.to_xml.to_s, xml_unencoded.to_xml.to_s)
  end

  def test_find_each()
    xml = @xml
    row_order = %w{8 7 6 4 5}
    REXML::XPath::each(xml, "//row") do |e|
      assert_equal(e.attributes["id"], row_order.delete_at(0))
    end
    assert_equal(0, row_order.length)

    row_order = %w{8 7 6 4 5}
    xml.find_each("//row") do |e|
      assert_equal(e.attributes["id"], row_order.delete_at(0))
    end
    assert_equal(0, row_order.length)
  end

  def test_find_first()
    xml = @xml
    x = REXML::XPath.first(xml, "//row")
    assert_not_nil(x)
    assert_equal("8", x.attributes["id"])

    x = xml.find_first("//row")
    assert_not_nil(x)
    assert_equal("8", x.attributes["id"])
  end

  def test_find_match()
    xml = @xml
    x = REXML::XPath.match(xml, "//row")
    assert_not_nil(x)
    assert_equal(5, x.length)
    assert_equal("8", x[0].attributes["id"])
    assert_equal("4", x[3].attributes["id"])

    x = xml.find_match("//row")
    assert_not_nil(x)
    assert_equal(5, x.length)
    assert_equal("8", x[0].attributes["id"])
    assert_equal("4", x[3].attributes["id"])
  end

  def test_deep_clone()
    xml = @xml
    xml2 = xml.deep_clone()
    assert_not_equal(xml.object_id, xml2.object_id)
    xml.write(xml_str1='')
    xml2.write(xml_str2='')
    assert_equal(xml_str1, xml_str2)
  end

  def test_node_loop_and_move()
    xml_full = @xml
    xml_part = MiqXml.load("<root/>", @xml_klass)

    count = 0
    xml_full.root.each_element do |e|
      xml_part.root << e
      count += 1
    end

    assert_equal(6, count)
  end

  def test_cdata()
    xml = MiqXml.newDoc(@xml_klass)
    xml.add_element('root')

    time = Time.now
		html_text = "<b>#{time}</b>"
    xml.root.add_cdata(html_text.gsub(",","\\,"))

    assert(xml.to_s.include?("![CDATA[<b>#{time}</b>]]"))
    assert_equal("<b>#{time}</b>", xml.root.text)
  end

  def test_delete_node()
    delete_node_helper(@xml_klass) do |node, root|
      node.remove!
    end

    delete_node_helper(@xml_klass) do |node, root|
      root.delete_element(node)
    end
  end

  def delete_node_helper(xml_klass)
    xml = MiqXml.load(@xml_string, @xml_klass)
    assert_kind_of(xml_klass::Document, xml)

    attr_ids = []
    xml.root.elements.each {|e| attr_ids << e.attributes[:id]}
    assert_equal(6, attr_ids.length)

    # Delete each element attached to the root node until all are removed.
    while (attr_ids.length > 0)
      # Get the first element
      del_node = xml.root.elements[1]

      # Yield to the method that will do the deletion
      yield(del_node, xml.root)

      removed_id = attr_ids.delete_at(0)
      assert_equal(removed_id, del_node.attributes[:id])

      count = 0
      xml.root.elements.each {|e| count += 1}
      assert_equal(attr_ids.length, count)
    end
  end

  def test_add_frozen_text()
    xml = @xml
    assert_kind_of(@xml_klass::Document, xml)

    frozen_text = "A&P".freeze
    assert_nothing_raised {xml.root.text = frozen_text}
    assert_equal("A&P", xml.root.text)
  end

  def test_write_method()
    # Test writing from the document
    @xml.write(test_string = "")
    assert_not_equal("", test_string)
    test_string = @xml.to_s
    assert_not_equal("", test_string)


    # Test writing from an element
    @xml.root.write(test_string = "")
    assert_not_equal("", test_string)
    test_string = @xml.root.to_s
    assert_not_equal("", test_string)
  end
end