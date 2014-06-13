class LdapUser < ActiveRecord::Base

  belongs_to :ldap_domain

  has_many   :ldap_managements, :dependent => :destroy
  has_many   :managers, :through => :ldap_managements, :foreign_key => "ldap_user_id", :source => :manager
  has_many   :inverse_managements, :class_name => "LdapManagement", :foreign_key => "manager_id", :dependent => :destroy
  has_many   :direct_reports,  :through => :inverse_managements, :source => :ldap_user

  belongs_to :vdi_user

  acts_as_miq_taggable

  include ReportableMixin

  DEFAULT_MAPPING = {
    :givenname         => :first_name,
    :sn                => :last_name,
    :displayname       => :display_name,
    :mail              => :mail,
    :streetaddress     => :address,
    :l                 => :city,
    :st                => :state,
    :postalcode        => :zip,
    :co                => :country,
    :title             => :title,
    :company           => :company,
    :department        => :department,
    :physicaldeliveryofficename => :office,
    :telephonenumber   => :phone,
    :facsimiletelephonenumber => :fax,
    :homephone         => :phone_home,
    :mobile            => :phone_mobile,
    :objectsid         => :sid,
    :whenchanged       => :whenchanged,
    :whencreated       => :whencreated,
    :samaccountname    => :sam_account_name,
    :userprincipalname => :upn,
    :dn                => :dn,
    :manager           => :manager,
    :memberof          => :memberof,
    :ldap_domain_id    => :ldap_domain_id
  }


  def self.sync_users(ldap_server)
    log_header = "MIQ(#{self.name}#sync_users) LDAP Server #{ldap_server.id} : <#{ldap_server.name}>"

    db_users = {}
    ldap_server.ldap_users.select([:id, :dn]).find_each {|u| db_users[u[:dn]] = u[:id]}
    $log.info "#{log_header} Initial DB User count: #{db_users.length}"

    sync_start_time = Time.now.utc
    user_count = creates = updates = 0

    # LDAP filters to return on record DB for people
    opts = {:attributes => ["dn"], :base => ldap_server.ldap.basedn, :return_result => false, :scope => :sub}
    opts[:filter] = Net::LDAP::Filter.eq("objectCategory", "Person")

    ldap_server.search(opts) do |entry|
      dn = MiqLdap.get_attr(entry, :dn)
      result = db_users.delete(dn)
      if result.nil?
        creates += 1
        ldap_server.ldap_users.build(:dn => dn)
      else
        updates += 1
      end

      # Log a message every once in a while so we know how far processing got.
      user_count += 1
      if user_count.remainder(1000).zero?
        ldap_server.save
        $log.info "#{log_header} Processed <#{user_count}> LDAP Users.  New User count: <#{creates}>  Updates: <#{updates}>"
      end

      ldap_server.save if creates.remainder(1000).zero?
    end
    ldap_server.save

    # Remaining Users are deletes
    deletes = db_users

    $log.info "#{log_header} Creates: #{creates}"
    $log.info "#{log_header} Updates: #{updates}"
    $log.info "#{log_header} Deletes: #{deletes.length}"

    delete_ids = deletes.collect {|dn,id| id}
    LdapUser.destroy(delete_ids)

    # Determine if a successful LDAP user scan has completed and either process all instances
    # or only ones that have changed since the last time.
    last_sync = ldap_server.last_user_sync
    if last_sync.nil?
      $log.info "#{log_header} Initiating full LDAP user sync.  Last User Sync: #{last_sync.inspect}"
      LdapUser.full_sync(ldap_server)
    else
      $log.info "#{log_header} Syncing LDAP User data from: #{last_sync.inspect}"
      LdapUser.update_records_since(ldap_server, last_sync)
    end
  end

  def self.full_sync(ldap_server)
    log_header = "MIQ(#{self.name}#update_records_since) LDAP Server #{ldap_server.id} : <#{ldap_server.name}>"
    $log.info "#{log_header} Starting full LDAP User sync"
    opts = {:return_result => false, :scope => :sub, :filter => Net::LDAP::Filter.eq("objectCategory", "Person")}

    rec_count = 0
    ldap_server.ldap_users.each do |rec|
      rec_count += 1
      options = opts.dup
      options[:base] = rec.dn
      ldap_server.search(options) {|entry| rec.update_record(entry)}
    end

    $log.info "#{log_header} Completed LDAP User sync for <#{rec_count}> records"
    rec_count
  end

  def self.update_records_since(ldap_server, updates_since)
    log_header = "MIQ(#{self.name}#update_records_since) LDAP Server #{ldap_server.id} : <#{ldap_server.name}>"
    opts = {:base => ldap_server.base_dn, :return_result => false, :scope => :sub, :filter => Net::LDAP::Filter.eq("objectCategory", "Person")}

    # LDAP whenchanged format example: "20121214170416.0Z"
    when_changed = updates_since.utc.iso8601(1).gsub(/[-:T]/,'')

    $log.info "#{log_header} Checking for updated records since <#{when_changed}>"
    opts[:filter] = opts[:filter] & Net::LDAP::Filter.ge("whenchanged", when_changed)

    rec_count = 0
    ldap_server.search(opts) do |entry|
      rec_count += 1
      dn = MiqLdap.get_attr(entry, :dn)
      rec = self.find_by_dn(dn)
    end

    $log.info "#{log_header} Completed LDAP User sync for <#{rec_count}> records updated since <#{when_changed}>"
    rec_count
  end

  def update_record(ldap_entry)
    # TODO: Attributes need to be exposed externally (yaml file) to allow for name changes
    attrs = {}
    [[:givenname, :first_name], [:sn, :last_name], [:displayname, :display_name], [:mail, :mail],
    [:streetaddress, :address], [:l, :city], [:st, :state], [:postalcode, :zip], [:co, :country],
    [:title, :title], [:company, :company], [:department, :department], [:physicaldeliveryofficename, :office],
    [:telephonenumber, :phone],[:facsimiletelephonenumber, :fax], [:homephone, :phone_home], [:mobile, :phone_mobile],
    [:objectsid, :sid], [:whenchanged, :whenchanged], [:whencreated, :whencreated]].each do |ldap_key, db_key|
      attrs[db_key] = MiqLdap.get_attr(ldap_entry, ldap_key)
    end

    attrs[:sid] = MiqLdap.sid_to_s(attrs[:sid]) if attrs.has_key?(:sid) && !attrs[:sid].blank?
    self.update_attributes(attrs)

    mgrs = ldap_entry[:manager].collect {|mgr_dn| self.class.find_by_dn(mgr_dn)}.compact
    self.managers.replace(mgrs)
  end
end
