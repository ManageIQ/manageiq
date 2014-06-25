require 'net/ldap'

class MiqLdap
  DEFAULT_LDAP_PORT      = 389
  DEFAULT_LDAPS_PORT     = 636
  DEFAULT_BIND_TIMEOUT   = 30
  DEFAULT_SEARCH_TIMEOUT = 30

  attr_accessor :basedn

  def initialize(options = {})
    log_prefix = "MIQ(MiqLdap.initialize)"
    @auth = options[:auth] || VMDB::Config.new("vmdb").config[:authentication]
    log_auth = VMDB::Config.clone_auth_for_log(@auth)
    $log.info("#{log_prefix} Server Settings: #{log_auth.inspect}")
    mode              = options.delete(:mode)            || @auth[:mode]
    @basedn           = options.delete(:basedn)          || @auth[:basedn]
    @user_type        = options.delete(:user_type)       || @auth[:user_type]
    @user_suffix      = options.delete(:user_suffix)     || @auth[:user_suffix]
    @bind_timeout     = options.delete(:bind_timeout)    || @auth[:bind_timeout]     || self.class.default_bind_timeout
    @search_timeout   = options.delete(:search_timeout)  || @auth[:search_timeout]   || self.class.default_search_timeout
    @follow_referrals = options.delete(:follow_referrals)|| @auth[:follow_referrals] || false
    defaults = {
      :host => @auth[:ldaphost],
      :port => @auth[:ldapport],
    }
    options = defaults.merge(options)
    options[:encryption] = { :method =>:simple_tls } if mode == "ldaps"

    options[:host] = self.resolve_host(options[:host], options[:port])

    # Make sure we do NOT log the clear-text password
    log_options = VMDB::Config.clone_auth_for_log(options)
    $log.info "options: #{log_options.inspect}"

    @ldap = Net::LDAP.new(options)
  end

  IP_REGEXP = /^(\d{1,3}\.){3}\d{1,3}$/

  def resolve_host(hosts, port)
    hosts = hosts.to_miq_a
    selected_host = nil

    hosts.each do |host|
      if host =~ IP_REGEXP
        addresses = host.to_miq_a # Host is already an IP Address, no need to resolve
      else
        begin
          canonical, aliases, type, *addresses = TCPSocket.gethostbyname(host) # Resolve hostname to IP Address
          $log.info("MiqLdap.connection: Resolved host [#{host}] has these IP Address: #{addresses.inspect}") if $log
        rescue => err
          $log.debug "Warning: '#{err.message}', resolving host: [host]"
          next
        end
      end

      addresses.each do |address|
        begin
          $log.info("MiqLdap.connection: Connecting to IP Address [#{address}]") if $log
          @conn = TCPSocket.new( address, port )
          selected_host = address
          break
        rescue => err
           $log.debug "Warning: '#{err.message}', connecting to IP Address [#{address}]"
        end
      end

      return selected_host if selected_host
    end

    raise Net::LDAP::LdapError.new( "unable to establish a connection to server" )
  end

  def bind(username, password)
    log_prefix = "MIQ(MiqLdap.bind)"
    @ldap.auth(username, password)
    begin
      $log.info("#{log_prefix} Binding to LDAP: Host: [#{@ldap.host}], User: [#{username}]...")
      Timeout::timeout(@bind_timeout) do
        if @ldap.bind
          $log.info("#{log_prefix} Binding to LDAP: Host: [#{@ldap.host}], User: [#{username}]... successful")
          return true
        else
          $log.warn("#{log_prefix} Binding to LDAP: Host: [#{@ldap.host}], User: [#{username}]... unsuccessful")
          return false
        end
      end
    rescue Exception => err
      $log.error("#{log_prefix} Binding to LDAP: Host: [#{@ldap.host}], User: [#{username}], '#{err.message}'")
      return false
    end
  end

  def bind_with_default
    @auth[:mode].include?('ldap') ? self.bind(@auth[:bind_dn], @auth[:bind_pwd]) : false
  end

  def ldap
    @ldap
  end

  def get(dn, attrs=nil)
     # puts "getObj: #{dn}"
    begin
      result = self.search(:base => dn, :scope => :base, :attributes => attrs)
    rescue Exception => err
      $log.error("MIQ(MiqLdap.get) '#{err.message}'")
    end
    return nil unless result
     # puts "result: #{result.inspect}"
    result.first
  end

  def self.get_attr(obj, attr)
    return nil unless obj.attribute_names.include?(attr)
    val = obj.send(attr)
    val = val.length == 1 ? val.first : val

    # The BERParser#read_ber adds the method "ber_identifier" to strings and arrays (line 122 in ber.rb) via instance_eval
    # This singleton method causes TypeError: singleton can't be dumped during Marshal.dump
    # Strip out the singleton method by creating a new string
    return val.is_a?(String) ? String.new(val) : val
  end

  def get_attr(obj, attr)
    MiqLdap.get_attr(obj, attr)
  end

  def search(opts, &blk)
    log_prefix = "MIQ(MiqLdap.search)"
    begin
      Timeout::timeout(@search_timeout) { _search(opts, &blk) }
    rescue TimeoutError
      $log.error("#{log_prefix} LDAP search timed out after #{@search_timeout} seconds")
      raise
    end
  end

  def _search(opts, seen=nil, &blk)
    log_prefix = "MIQ(MiqLdap._search)"
    raw_opts = opts.dup
    opts[:scope]            = self.scope(opts[:scope]) if opts[:scope]
    if opts[:filter]
      opts[:filter]         = self.filter_construct(opts[:filter]) unless opts[:filter].kind_of?(Net::LDAP::Filter)
    end
    opts[:return_referrals] = @follow_referrals
    seen                  ||= {:objects => [], :referrals => {}}
    $log.debug("#{log_prefix} opts: #{opts.inspect}")

    if block_given?
      opts[:return_result] = false
      return @ldap.search(opts) { |entry| yield entry if block_given? }
    else
      result = @ldap.search(opts)
      unless ldap_result_ok?
        $log.warn("#{log_prefix} LDAP Search unsuccessful, '#{@ldap.get_operation_result.message}', Code: [#{@ldap.get_operation_result.code}], Host: [#{@ldap.host}]")
        return []
      end
      return @follow_referrals ? chase_referrals(result, raw_opts, seen) : result
    end
  end

  def ldap_result_ok?(follow_referrals = @follow_referrals)
    return true if @ldap.get_operation_result.code == 0
    return true if @ldap.get_operation_result.code == 10 && follow_referrals
    return false
  end

  def chase_referrals(objs, opts, seen)
    log_prefix = "MIQ(MiqLdap.chase_referrals)"
    return objs if objs.empty?

    res = []
    objs.each do |o|
      if o.attribute_names.include?(:search_referrals)
        o.search_referrals.each do |ref|
          scheme, userinfo, host, port, registry, dn, opaque, query, fragment = URI.split(ref)
          port ||= self.class.default_ldap_port(scheme)
          dn = self.normalize(dn.split("/").last)
          next if seen[:objects].include?(dn)

          begin
            $log.debug("#{log_prefix} Chasing referral: #{ref}")

            handle = seen[:referrals][host]
            if handle.nil?
              handle = self.class.new(:auth => {:ldaphost => host, :ldapport => port, :mode => scheme, :follow_referrals => @follow_referrals})
              unless handle.bind(@auth[:bind_dn], @auth[:bind_pwd])
                $log.warn("#{log_prefix} Unable to chase referral: #{ref}, bind with user: [#{@auth[:bind_dn]}] was unsuccessful")
                next
              end
              seen[:referrals][host] = handle
            end

            seen[:objects] << dn
            ref_res = handle._search(opts.merge(:base => dn), seen)
            $log.debug("#{log_prefix} Referral: #{ref}, returned [#{ref_res.length}] objects")
            res += ref_res
          rescue Net::LDAP::LdapError => err
            $log.warn("#{log_prefix} Unable to chase referral [#{ref}] because #{err.message}")
          end
        end
      else
        res << o
      end
    end

    return res
  end

  def scope(s)
    case s.to_sym
    when :base
      Net::LDAP::SearchScope_BaseObject
    when :one
      Net::LDAP::SearchScope_SingleLevel
    when :sub
      Net::LDAP::SearchScope_WholeSubtree
    else
      raise "scope must be one of :base, :one or :sub"
    end
  end

  def filter_construct(filter_str)
    begin
      Net::LDAP::Filter.construct(filter_str)
    rescue Exception => err
      raise err.message
    end
  end

  def filter(op, *args)
    Net::LDAP::Filter.send(op, *args)
  end

  def self.object_sid_filter(sid_string)
    Net::LDAP::Filter.eq("objectSID", sid_string)
  end

  def self.filter_users_only
    Net::LDAP::Filter.eq("objectClass", "person") & Net::LDAP::Filter.ne("objectClass", "computer")
  end

  def self.filter_groups_only
    Net::LDAP::Filter.eq("objectClass", "group")
  end

  def normalize(dn)
    return if dn.nil?
    dn.split(",").collect {|i| i.downcase.strip}.join(",")
  end

  def is_dn?(str)
    str =~ /^([a-z|0-9|A-Z]+ *=[^,]+[,| ]*)+$/ ? true : false
  end

  def fqusername(username)
    return username if self.is_dn?(username)

    user_type = @user_type.split("-").first
    user_prefix = @user_type.split("-").last
    user_prefix = "cn" if user_prefix == "dn"
    case user_type
    when "upn", "userprincipalname"
      return username if @user_suffix.blank?
      return username if username =~ /^.+@.+$/ # already qualified with user@domain

      return "#{username}@#{@user_suffix}"
    when"mail"
      username = "#{username}@#{@user_suffix}" unless @user_suffix.blank? || username =~ /^.+@.+$/
      dbuser = User.find_by_email(username.downcase)
      dbuser = User.find_by_userid(username.downcase) unless dbuser
      return dbuser.userid if dbuser && dbuser.userid

      return username
    when "dn"
      return "#{user_prefix}=#{username},#{@user_suffix}"
    end
  end

  def get_user_object(username, user_type = nil)
    log_prefix = "MIQ(MiqLdap.get_user_object)"

    user_type ||= @user_type.split("-").first
    user_type = "dn" if self.is_dn?(username)
    begin
      search_opts = {:base => @basedn, :scope => :sub, :attributes => ["*", "memberof"]}

      case user_type
      when "upn", "userprincipalname", "mail"
        user_type = "userprincipalname" if user_type == "upn"
        search_opts[:filter] = "(#{user_type}=#{username})"
      when "dn"
        search_opts.merge!(:base => username, :scope => :base)
      when "sid"
        search_opts[:filter] = self.class.object_sid_filter(username)
      end

      $log.info("#{log_prefix} Type: [#{user_type}], Base DN: [#{@basedn}], Filter: <#{search_opts[:filter]}>")
      obj = self.search(search_opts)
    rescue Exception => err
      $log.error("#{log_prefix} '#{err.message}'")
      obj = nil
    end
    obj.first if obj
  end

  def get_user_info(username, user_type='mail')
    user = get_user_object(username, user_type)
    return nil if user.nil?

    udata = {}
    udata[:first_name]   = MiqLdap.get_attr(user, :givenname)
    udata[:last_name]    = MiqLdap.get_attr(user, :sn)
    udata[:display_name] = MiqLdap.get_attr(user, :displayname)
    udata[:mail]         = MiqLdap.get_attr(user, :mail)
    udata[:address]      = MiqLdap.get_attr(user, :streetaddress)
    udata[:city]         = MiqLdap.get_attr(user, :l)
    udata[:state]        = MiqLdap.get_attr(user, :st)
    udata[:zip]          = MiqLdap.get_attr(user, :postalcode)
    udata[:country]      = MiqLdap.get_attr(user, :co)

    udata[:title]        = MiqLdap.get_attr(user, :title)
    udata[:company]      = MiqLdap.get_attr(user, :company)
    udata[:department]   = MiqLdap.get_attr(user, :department)
    udata[:office]       = MiqLdap.get_attr(user, :physicaldeliveryofficename)
    udata[:phone]        = MiqLdap.get_attr(user, :telephonenumber)
    udata[:fax]          = MiqLdap.get_attr(user, :facsimiletelephonenumber)
    udata[:phone_home]   = MiqLdap.get_attr(user, :homephone)
    udata[:phone_mobile] = MiqLdap.get_attr(user, :mobile)
    udata[:sid]          = MiqLdap.get_sid(user)

    managers = []
    user[:manager].each { |m| managers << get(m) } unless user[:manager].blank?
    udata[:manager]       = managers.empty? ? nil : MiqLdap.get_attr(managers.first, :displayname)
    udata[:manager_phone] = managers.empty? ? nil : MiqLdap.get_attr(managers.first, :telephonenumber)
    udata[:manager_mail]  = managers.empty? ? nil : MiqLdap.get_attr(managers.first, :mail)

    assistants           = []
    delegates            = user[:publicdelegates]
    delegates.each { |d|  assistants << get(d) } unless delegates.nil?
    udata[:assistant]       = assistants.empty? ? nil : MiqLdap.get_attr(assistants.first, :displayname)
    udata[:assistant_phone] = assistants.empty? ? nil : MiqLdap.get_attr(assistants.first, :telephonenumber)
    udata[:assistant_mail]  = assistants.empty? ? nil : MiqLdap.get_attr(assistants.first, :mail)

    return udata
  end


  def get_memberships(obj, max_depth = 0, attr=:memberof, followed = [], current_depth = 0)
    log_prefix = "MIQ(MiqLdap.get_memberships)"

    current_depth += 1

    $log.debug "#{log_prefix} Enter get_memberships: #{obj.inspect}"
    $log.debug "#{log_prefix} Enter get_memberships: #{obj.dn}, max_depth: #{max_depth}, current_depth: #{current_depth}, attr: #{attr}"
    result = []
    # puts "obj #{obj.inspect}"
    groups = MiqLdap.get_attr(obj, attr).to_miq_a
    $log.debug "#{log_prefix} Groups: #{groups.inspect}"
    return result unless groups

    groups.each {|group|
      # puts "group #{group}"
      gobj = self.get(group, [:cn, attr])
      dn   = nil
      cn   = nil
      if gobj.nil?
        $log.debug "#{log_prefix} Group: DN: #{group} returned a nil object, CN will be extracted from DN, memberships will not be followed"
        self.normalize(group) =~ /^cn[ ]*=[ ]*([^,]+),/
        cn = $1
      else
        dn = self.normalize(MiqLdap.get_attr(gobj, :dn))
        cn = MiqLdap.get_attr(gobj, :cn)
      end

      if cn.nil?
        suffix = gobj.nil? ? "unable to extract CN from DN" : "has no CN"
        $log.debug "#{log_prefix} Group: #{group} #{suffix}, skipping"
      else
        $log.debug "#{log_prefix} Group: DN: #{group}, extracted CN: #{cn}"
        result.push(cn.strip)
      end

      unless dn.nil? || followed.include?(dn)
        followed.push(dn)
        result.concat(self.get_memberships(gobj, max_depth, attr, followed, current_depth)) unless max_depth > 0 && current_depth >= max_depth
      end

    }
    $log.debug "#{log_prefix} Exit get_memberships: #{obj.dn}, result: #{result.uniq.inspect}"
    result.uniq
  end

  def get_organizationalunits(basedn = nil, filter = nil)
    basedn ||= @basedn
    filter ||= "(ObjectCategory=organizationalUnit)"
    result = self.search(:base => basedn, :scope => :sub, :filter => filter)
    return nil unless result
    result.collect {|o| [self.get_attr(o, :dn), self.get_attr(o, :name)]}
  end

  def self.get_sid(entry)
    MiqLdap.sid_to_s(MiqLdap.get_attr(entry, :objectsid))
  end

  def self.default_ldap_port(scheme="ldap")
    case scheme
    when "ldap"
      DEFAULT_LDAP_PORT
    when "ldaps"
      DEFAULT_LDAPS_PORT
    else
      raise "unknown scheme, '#{scheme}'"
    end
  end

  def self.default_bind_timeout
    value = VMDB::Config.new("vmdb").config[:authentication][:bind_timeout] || DEFAULT_BIND_TIMEOUT
    value = value.to_i_with_method if value.respond_to?(:to_i_with_method)
    value
  end

  def self.default_search_timeout
    value = VMDB::Config.new("vmdb").config[:authentication][:search_timeout] || DEFAULT_SEARCH_TIMEOUT
    value = value.to_i_with_method if value.respond_to?(:to_i_with_method)
    value
  end

  def self.using_ldap?
    VMDB::Config.new("vmdb").config[:authentication][:mode].include?('ldap')
  end

  def self.resolve_ldap_host?
    if @resolve_ldap_host.nil?
      @resolve_ldap_host = VMDB::Config.new("vmdb").config[:authentication][:resolve_ldap_host]
      @resolve_ldap_host = false if @resolve_ldap_host.nil?
    end

    @resolve_ldap_host
  end

  def self.sid_to_s(data)
    return "" if data.blank?

    sid = []
    sid << data.ord.to_s

    rid = ""
    (6).downto(1) do |i|
      rid += byte2hex(data[i,1].ord)
    end
    sid << rid.to_i.to_s

    sid += data.unpack("bbbbbbbbV*")[8..-1]
    "S-" + sid.join('-')
  end

  def self.byte2hex(b)
    ret = '%x' % (b.to_i & 0xff)
    ret = '0' + ret if ret.length < 2
    ret
  end
end # class MiqLdap
