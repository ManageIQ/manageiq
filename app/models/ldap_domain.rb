class LdapDomain < ActiveRecord::Base
  belongs_to :ldap_region

  has_many :ldap_servers, :dependent => :destroy
  has_many :ldap_groups,  :dependent => :destroy
  has_many :ldap_users,   :dependent => :destroy

  default_value_for :get_direct_groups,          true
  default_value_for :group_membership_max_depth, 2
  default_value_for :bind_timeout,               30
  default_value_for :search_timeout,             30

  attr_accessor :ldap

  acts_as_miq_taggable

  include ReportableMixin
  include AuthenticationMixin

  def connect(server = nil)
    error_msgs = []
    servers = server.nil? ? self.ldap_servers : [server]

    servers.each do |s|
      options = {}
      options[:auth] = {:ldaphost => s.hostname, :ldapport => s.port}
      options[:mode]           = s.mode
      options[:basedn]         = self.base_dn
      options[:user_type]      = self.user_type
      options[:user_suffix]    = self.user_suffix
      options[:domain_prefix]  = domain_prefix
      options[:bind_timeout]   = self.bind_timeout
      options[:search_timeout] = self.search_timeout
      #options[:] = (self.follow_referrals)

      @ldap = MiqLdap.new(options)
      begin
        @ldap.bind(*self.auth_user_pwd)
      rescue => err
        @ldap = nil
        error_msgs << err.message
      end
      return @ldap unless @ldap.nil?
    end

    message = "Failed to connect to Ldap servers for domain: <#{self.name}>.  Servers: <#{servers.collect(&:hostname)}>"
    $log.error("#{message}, #{error_msgs.join("\n")}")
    raise MiqException::Error, message
  end

  def connected?
    @ldap ? true : false
  end

  def verify_credentials(server = nil)
    begin
      result = self.connect(server)
    rescue Exception => err
      raise MiqException::Error, err.message
    else
      raise MiqException::Error, "Authentication failed" unless result
    end

    result
  end

  def search(opts, &blk)
    @ldap.search(opts, &blk)
  end

  def sync_users_and_groups
    self.sync_users
    # self.sync_groups
  end

  def sync_users
    start_sync_time = Time.now.utc
    LdapUser.sync_users(self)
    self.update_attribute(:last_user_sync, start_sync_time)
  end

  def find_by_dn(dn)
    @ldap.get_user_object(dn, 'dn')
  end

  def find_by_sid(sid)
    @ldap.get_user_object(sid, 'sid')
  end

  def self.ldap_user_name_mapping
    LdapUser::DEFAULT_MAPPING
  end

  def ldap_user_name_mapping
    # Allow individual domains to override the mapping
    self.class.ldap_user_name_mapping
  end

  def is_valid?
    return false if self.ldap_servers.size.zero?
    return false if self.auth_user_pwd.nil?
    return false if self.base_dn.blank?
    true
  end

  def user_search(options, search_filters=nil, search_attrs=nil, result_key=:objectsid)
    results = {}
    self.connect unless connected?

    search_options = {:scope => :sub, :base => self.ldap.basedn}
    search_options[:size] = options[:size] || 200

    # Default filter - Only return users
    search_options[:filter] = search_filters.nil? ? self.build_user_search_filter(options) : search_filters
    return {} if search_options[:filter].nil?

    # Limit attributes to collect
    search_options[:attributes] = search_attrs.nil? ? self.ldap_user_name_mapping.keys : search_attrs

    self.search(search_options) do |entry|
      user = build_user_hash_from_entry(entry, search_options[:attributes])
      results[user[result_key]] = user
    end

    results
  end

  def build_user_hash_from_entry(entry, attributes)
    user = {:objectsid => MiqLdap.get_sid(entry), :ldap_domain_id => self.id}

    attributes.each do |attr|
      attr_sym = attr.to_sym
      next if [:objectsid, :ldap_domain_id].include?(attr_sym)
      if [:manager, :memberof].include?(attr_sym)
        user["#{attr}_name".to_sym] = collect_property_names(entry, attr_sym)
      else
        user[attr_sym] = MiqLdap.get_attr(entry, attr_sym)
      end
    end

    user
  end

  def collect_property_names(entry, attr_sym)
    values = MiqLdap.get_attr(entry, attr_sym)
    values.to_miq_a.collect {|dn| dn.split(",").first.split("=").last}.join(", ")
  end

  def collect_property_dns(entry, attr_sym)
    values = MiqLdap.get_attr(entry, attr_sym)
    values.to_miq_a.join("; ")
  end

  def build_user_search_filter(options)
    result = MiqLdap.filter_users_only
    options[:filters].to_miq_a.each do |fh|
      filter = if fh[:field] == 'memberof_name'
        manager_display_name_search(options, :name, fh, MiqLdap.filter_groups_only, :memberof)
      elsif fh[:field] == 'manager_name'
        manager_display_name_search(options, :displayname, fh, MiqLdap.filter_users_only, :manager)
      else
        result & self.ldap.filter(:eq, fh[:field], fh[:value])
      end
      return nil if filter.nil?
      result = result & filter
    end

    result
  end

  def manager_display_name_search(options, filter_key, filter_hash, base_search_filter, new_filter_key)
    # If filter value is '*' we only need to search with entries that have a value for the field.
    return self.ldap.filter(:eq, new_filter_key, filter_hash[:value]) if filter_hash[:value] == '*'

    # First we need to lookup entries by displayname to build new filter
    result = nil
    search_filters = base_search_filter & self.ldap.filter(:eq, filter_key, filter_hash[:value])
    self.user_search(options, search_filters, [:dn, filter_key], :dn).each do |dn, props|
      filter = self.ldap.filter(:eq, new_filter_key, dn)
      result = result.nil? ? filter : result | filter
    end
    result
  end

end
