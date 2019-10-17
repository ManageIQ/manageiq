class SystemService < ApplicationRecord
  belongs_to :vm_or_template
  belongs_to :vm,           :foreign_key => :vm_or_template_id
  belongs_to :miq_template, :foreign_key => :vm_or_template_id
  belongs_to :host
  belongs_to :host_service_group
  has_one    :cloud_service, :dependent => :nullify

  serialize :dependencies, Hash

  scope :running_systemd_services, -> { where(:systemd_active => 'active', :systemd_sub => 'running') }
  scope :failed_systemd_services, -> { where(:systemd_active => 'failed').or(where(:systemd_sub => 'failed')) }
  scope :host_service_group_systemd, ->(host_service_group_id) { where(:host_service_group_id => host_service_group_id) }
  scope :host_service_group_running_systemd, lambda { |host_service_group_id|
    running_systemd_services.merge(host_service_group_systemd(host_service_group_id))
  }
  scope :host_service_group_failed_systemd, lambda { |host_service_group_id|
    failed_systemd_services.merge(host_service_group_systemd(host_service_group_id))
  }

  SVC_TYPES = {
    # Type     Display
    ""    => "",
    "1"   => N_("Kernel Driver"),
    "2"   => N_("File System Driver"),
    "4"   => N_("Service Adapter"),
    "8"   => N_("Recognizer Driver"),
    "16"  => N_("Win32 Own Process"),
    "32"  => N_("Win32 Shared Process"),
    "256" => N_("Interactive"),
    "272" => N_("Win32 Own Process, Interactive"),
    "288" => N_("Win32 Shared Process, Interactive"),
  }

  START_TYPES = {
    # Type     Display
    ""  => "",
    "0" => N_("Boot Start"),
    "1" => N_("System Start"),
    "2" => N_("Automatic"),
    "3" => N_("Manual"),
    "4" => N_("Disabled")
  }

  def start
    s = self['start']
    _(START_TYPES[s]) || s
  end

  def svc_type
    svc = self['svc_type']
    _(SVC_TYPES[svc]) || svc
  end

  def self.add_elements(parent, xmlNode)
    add_missing_elements(parent, xmlNode, "services")
  end

  def self.add_missing_elements(parent, xmlNode, findPath)
    hashes = xml_to_hashes(xmlNode, findPath)
    EmsRefresh.save_system_services_inventory(parent, hashes, :scan) if hashes
  end

  def self.xml_to_hashes(xmlNode, findPath, typeName = nil)
    el = XmlFind.findElement(findPath, xmlNode.root)
    return nil unless MiqXml.isXmlElement?(el)

    result = []
    el.each_element do |e|
      nh = e.attributes.to_h
      next unless typeName.nil? || nh[:typename] == typeName

      e.each_element do |e2|
        case e2.name
        when "depend_on_service"
          nh[:depend_on_service] = (nh[:depend_on_service].nil? ? e2.attributes[:name] : nh[:depend_on_service] + " " + e2.attributes[:name])
        when "depend_on_group"
          nh[:depend_on_group] = (nh[:depend_on_group].nil? ? e2.attributes[:name] : nh[:depend_on_group] + " " + e2.attributes[:name])
        when "enable_run_level"
          nh[:enable_run_levels] = (nh[:enable_run_levels].nil? ? e2.attributes[:value] : nh[:enable_run_levels] + e2.attributes[:value])
        when "disable_run_level"
          nh[:disable_run_levels] = (nh[:disable_run_levels].nil? ? e2.attributes[:value] : nh[:disable_run_levels] + e2.attributes[:value])
        end
      end

      result << nh
    end
    result
  end

  def required_by
    dependencies[:required_by]
  end

  def wanted_by
    dependencies[:wanted_by]
  end

  def required_by=(val)
    dependencies[:required_by] = val
  end

  def wanted_by=(val)
    dependencies[:wanted_by] = val
  end
end
