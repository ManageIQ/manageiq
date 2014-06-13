class VdiUser < ActiveRecord::Base
  has_many   :vdi_sessions
  has_and_belongs_to_many :vdi_desktops
  has_and_belongs_to_many :vdi_desktop_pools
  has_many   :ems_events
  has_one    :ldap, :class_name => 'LdapUser', :dependent => :destroy

  include ReportableMixin
  include ArCountMixin

  ## Relationships
  # :managers, :groups

  def self.find_user(user)
    if user =~ /^S\-[0-9]\-[0-9]\-[0-9]{2,2}\-[0-9]+\-[0-9]+\-[0-9]+/i
      self.find_by_uid_ems(user)
    else
      self.first(:conditions => ["lower(name) = ?", user.downcase])
    end
  end

  def sid
    self.uid_ems
  end

  def desktop_assignment_add(vdi_desktop)
    if !self.vdi_desktops.include?(vdi_desktop)
      vdi_desktop.vdi_users << self
      create_assignment_event(:vm_vdi_user_assigned, vdi_desktop)
    end
  end

  def desktop_assignment_delete(vdi_desktop)
    if self.vdi_desktops.include?(vdi_desktop)
      create_assignment_event(:vm_vdi_user_unassigned, vdi_desktop)
      vdi_desktop.vdi_users.delete(self)
    end
  end

  def create_assignment_event(event_type, vdi_desktop)
    event = {
      :event_type            => event_type,
      :timestamp             => Time.now,

      :vdi_user_id           => self.id,
      :vdi_user_name         => self.name,

      :vdi_desktop_id        => vdi_desktop.id,
      :vdi_desktop_name      => vdi_desktop.name
    }

    if dp = vdi_desktop.vdi_desktop_pool
      event.merge!({
        :vdi_desktop_pool_id   => dp.id,
        :vdi_desktop_pool_name => dp.name
      })
    end

    if vm = vdi_desktop.vm_or_template
      event.merge!({
        :vm_or_template_id     => vm.id,
        :vm_name               => vm.name,
        :vm_location           => vm.path
      })
    end

    EmsEvent.add(vm.ems_id, event) unless vm.nil?
  end

  def find_ldap_entry(domains=nil)
    if self.ldap
      domain = self.ldap.ldap_domain
      domain.connect unless domain.connected?

      entry = domain.find_by_sid(self.sid)
      return [entry, domain]
    end

    user_domain = self.domain_name.try(:downcase)
    domains.each do |domain|
      if domain.base_dn.downcase.split(",").include?("dc=#{user_domain}")
        domain.connect unless domain.connected?
        entry = domain.find_by_sid(self.sid)
        return [entry, domain] if entry && MiqLdap.get_attr(entry, :whencreated)
      end
    end

    nil
  end

  def domain_name
    return nil unless self.name.include?('\\')
    domain = self.name.split('\\').first.split('.').first
  end

  def update_record_from_ldap(ldap_entry=nil, domains=nil)
    ldap_entry, domain = find_ldap_entry(domains) if ldap_entry.nil?
    return if ldap_entry.nil?

    attributes = self.class.ldap_search_fields.transpose.last
    entry_hash = domain.build_user_hash_from_entry(ldap_entry, attributes)
    self.create_ldap_user_from_hash(entry_hash)

    # # mgrs = ldap_entry[:manager].collect {|mgr_dn| self.class.find_by_dn(mgr_dn)}.compact
    # # self.managers.replace(mgrs)
    # attrs
  end

  def self.ldap_search_fields
    [['Login ID',                   'samaccountname'],
     ['First Name',                 'givenname'],
     ['Last Name',                  'sn'],
     ['Display Name',               'displayname'],
     ['E-mail',                     'mail'],
     ['Department',                 'department'],
     ['Title',                      'title'],
     ['Office',                     'physicaldeliveryofficename'],
     ['Street Address',             'streetaddress'],
     ['City',                       'l'],
     ['State',                      'st'],
     ['Zip',                        'postalcode'],
     ['Country',                    'co'],
     ['Company',                    'company'],
     ['Phone',                      'telephonenumber'],
     ['Phone - Home',               'homephone'],
     ['Phone - Mobile',             'mobile'],
     ['Fax',                        'facsimiletelephonenumber'],
     ['User Principal Name',        'userprincipalname'],
     ['Distinguished Name',         'dn'],
     ['Group Name (member of)',     'memberof_name'],
     ['Manager Name',               'manager_name'],
     ['SID',                        'objectsid']
     ].sort_by {|a| a.first}
  end

  def self.ldap_search_queue(options)
    ldap_region = LdapRegion.find_by_id(options[:ldap_region_id])
    ldap_domain = LdapDomain.find_by_id(options[:ldap_domain_id])

    if ldap_domain.nil?
      task_description = "Search for LDAP Users on LDAP Region '#{ldap_region.name}'"
    else
      task_description = "Search for LDAP Users on LDAP Domain '#{ldap_domain.name}' in LDAP Region '#{ldap_region.name}'"
    end
    queue_task(:ldap_search, task_description, options)
  end

  def self.ldap_search(options, task_id)
    begin
      task = MiqTask.find_by_id(task_id)
      task.update_status(MiqTask::STATE_ACTIVE, MiqTask::STATUS_OK, "Running task")

      # Find where to send the search request
      ldap_target = LdapDomain.find_by_id(options[:ldap_domain_id])
      ldap_target = LdapRegion.find_by_id(options[:ldap_region_id]) if ldap_target.nil?

      results = ldap_target.user_search(options)

      # Add the ID of existing VDI User instances
      self.where(:uid_ems => results.keys).each do |vdi_user|
        results[vdi_user.uid_ems][:id] = vdi_user.id
      end

      results = results.to_a.transpose.last
      task.task_results = results
      task.update_status(MiqTask::STATE_FINISHED, MiqTask::STATUS_OK, "Task Complete")
    rescue => err
      task.update_status(MiqTask::STATE_FINISHED, MiqTask::STATUS_ERROR, err.to_s)
      $log.log_backtrace(err)
    end
  end

  def self.queue_task(task_name, task_description, *args)
    log_header = "MIQ(#{self.name}.queue_task)"

    task = MiqTask.create(:name => task_description, :userid => User.current_userid || 'system')

    $log.info("#{log_header} Queuing VdiUser task <#{task_name}>  Description: #{task_description}")
    cb = {:class_name => task.class.name, :instance_id => task.id, :method_name => :queue_callback_on_exceptions, :args => ['Finished']}
    MiqQueue.put(
      :class_name   => self.name,
      :args         => [*args, task.id],
      :method_name  => task_name,
      :miq_callback => cb,
      :zone         => MiqServer.my_zone,
      :priority     => MiqQueue::HIGH_PRIORITY
    )
    task.state_queued
    task
  end

  def self.import_from_ui(new_user_hashes)
    results = {:error => 0, :ok => 0, :total => new_user_hashes.length, :success_msgs => [], :error_msgs => [], :warning_msgs => []}
    transaction do
      new_user_hashes.each do |user_data|
        begin
          results[:ok] += 1
          self.create_from_ldap(user_data)
        rescue
          results[:error] += 1
        end
      end
    end

    results[:success_msgs] << "Successfully created #{results[:ok]} VDI User(s)" unless results[:ok].zero?
    results[:error_msgs]   << "Failed to create #{results[:error]} VDI User(s)"  unless results[:error].zero?

    results
  end

  def self.create_from_ldap(user_data)
    vu = self.create(:uid_ems => user_data[:objectsid], :name => self.user_name_from_ldap(user_data))
    vu.create_ldap_user_from_hash(user_data)
  end

  def create_ldap_user_from_hash(user_data)
    mapping = LdapDomain.ldap_user_name_mapping
    ldap_data = {}
    user_data.each do |k,v|
      key = mapping[k]
      ldap_data[key] = v if key && !v.nil?
    end
    self.create_ldap(ldap_data)
  end

  def self.user_name_from_ldap(user_data)
    if user_data[:userprincipalname].try(:include?, '@')
      name, domain = user_data[:userprincipalname].split("@")
      return "#{domain}\\#{name}"
    else
      user_data[:samaccountname]
    end
  end

  def self.delete_users_queue(ids)
    queue_task(:delete_users, "Delete #{ids.length} VDI User(s)", ids)
  end

  def self.delete_users(ids, task_id)
    begin
      results = {:assigned => 0, :error => 0, :ok => 0, :total => ids.length, :success_msgs => [], :error_msgs => [], :warning_msgs => []}
      task = MiqTask.find_by_id(task_id)
      task.update_status(MiqTask::STATE_ACTIVE, MiqTask::STATUS_OK, "Running task")
      self.where(:id => ids).each do |vdi_user|
        begin
          if vdi_user.has_assigments?
            results[:assigned] += 1
          else
            vdi_user.destroy
            results[:ok] += 1
          end
        rescue MiqException::Error
          results[:error] += 1
        end
      end

      results[:success_msgs] << "Successfully removed #{results[:ok]} VDI User(s)" unless results[:ok].zero?
      results[:error_msgs]   << "Failed to remove #{results[:error]} VDI User(s) due to existing Desktop or Desktop Pool assignment" unless results[:assigned].zero?
      results[:error_msgs]   << "Failed to remove #{results[:error]} VDI User(s)"  unless results[:error].zero?
      task.task_results = results
      task.update_status(MiqTask::STATE_FINISHED, MiqTask::STATUS_OK, "Task Complete")
    rescue => err
      task.update_status(MiqTask::STATE_FINISHED, MiqTask::STATUS_ERROR, err.to_s)
      $log.log_backtrace(err)
    end
  end

  def has_assigments?
    return true if !self.vdi_desktop_pools.size.zero? || !self.vdi_desktops.size.zero?
    false
  end

end
