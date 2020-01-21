class Account < ApplicationRecord
  belongs_to :vm_or_template
  belongs_to :host

  include RelationshipMixin
  self.default_relationship_type = "accounts"

  def self.add_elements(parent, xmlNode)
    user_map = add_missing_elements(parent, xmlNode, "accounts/users", "user")
    add_missing_elements(parent, xmlNode, "accounts/groups", "group")
    add_missing_relationships(parent, user_map)
  end

  def self.add_missing_elements(parent, xmlNode, findPath, typeName)
    hashes = xml_to_hashes(xmlNode, findPath, typeName)
    return if hashes.nil?

    new_accts = []
    member_map = {}
    deletes = parent.accounts.where(:accttype => typeName).pluck(:id, :name)

    hashes.each do |nh|
      member_map[nh[:name]] = nh.delete(:members)

      found = parent.accounts.find_by(:name => nh[:name], :accttype => typeName)
      found.nil? ? new_accts << nh : found.update(nh)
      deletes.delete_if { |ele| ele[1] == nh[:name] }
    end

    parent.accounts.create(new_accts)
    # Delete the IDs that correspond to the remaining names in the current list.
    _log.info("Account deletes: #{deletes.inspect}") unless deletes.empty?
    deletes = deletes.transpose[0]
    Account.destroy(deletes) unless deletes.nil?

    member_map
  end

  def self.add_missing_relationships(parent, user_map)
    return if user_map.nil?

    # Only need to check one direction, as both directions are implied in the xml
    user_map.each do |name, curr_groups|
      acct = parent.accounts.find_by(:name => name, :accttype => 'user')
      prev_groups = acct.groups.collect(&:name)

      # Remove the common elements from both groups to determine the add/deletes
      common = prev_groups & curr_groups
      prev_groups -= common
      curr_groups -= common

      prev_groups.each { |group| acct.remove_group(parent.accounts.find_by(:name => group, :accttype => 'group')) }
      curr_groups.each { |group| acct.add_group(parent.accounts.find_by(:name => group, :accttype => 'group')) }
    end
  end

  def self.xml_to_hashes(xmlNode, findPath, typeName)
    el = XmlFind.findElement(findPath, xmlNode.root)
    return nil unless MiqXml.isXmlElement?(el)

    result = []
    el.each_element do |e|
      nh = e.attributes.to_h
      nh[:accttype] = typeName

      # Change the specific id type to an acctid
      nh[:acctid] = nh.delete("#{typeName}id".to_sym)
      nh[:acctid] = nil unless nh[:acctid].respond_to?(:to_int) || nh[:acctid].to_s =~ /^-?[0-9]+$/
      # Convert to signed integer values for acctid
      nh[:acctid] = [nh[:acctid].to_i].pack("I").unpack("i")[0] unless nh[:acctid].nil?

      # Find the users for this group / groups for this user
      nh[:members] = []
      e.each_element { |e2| nh[:members] << e2.attributes['name'] }

      result << nh
    end
    result
  end

  def self.accttype_opposite(accttype)
    case accttype
    when 'group' then 'user'
    when 'user' then 'group'
    end
  end

  def accttype_opposite
    Account.accttype_opposite(accttype)
  end

  def with_valid_account_type(valid_account_type)
    if accttype == valid_account_type
      yield
    else
      raise _("Cannot call method '%{caller}' on an Account of type '%{type}'") % {:caller => caller[0][/`.*'/][1..-2],
                                                                                   :type   => accttype}
    end
  end

  # Relationship mapped methods
  def users
    with_valid_account_type('group') { children }
  end

  def add_user(owns)
    with_valid_account_type('group') { add_child(owns) }
  end

  def remove_user(owns)
    with_valid_account_type('group') { remove_child(owns) }
  end

  def remove_all_users
    with_valid_account_type('group') { remove_all_children(:of_type => self.class.name) }
  end

  def groups
    with_valid_account_type('user') { parents }
  end

  def add_group(owner)
    with_valid_account_type('user') { add_parent(owner) }
  end

  def remove_group(owner)
    with_valid_account_type('user') { remove_parent(owner) }
  end

  def remove_all_groups
    with_valid_account_type('user') { remove_all_parents(:of_type => self.class.name) }
  end

  # Type ambivalent relationship methods
  #
  # FIXME: Why not use .pluralize?
  #
  def members
    send("#{accttype_opposite}s")
  end

  def add_member(member)
    send("add_#{accttype_opposite}", member)
  end

  def remove_member(member)
    send("remove_#{accttype_opposite}", member)
  end

  def remove_all_members
    send("remove_all_#{accttype_opposite}s")
  end
end
