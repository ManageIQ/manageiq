class SystemService < ApplicationRecord
  belongs_to :vm_or_template
  belongs_to :vm,           :foreign_key => :vm_or_template_id
  belongs_to :miq_template, :foreign_key => :vm_or_template_id
  belongs_to :host
  belongs_to :host_service_group

  serialize :dependencies, Hash

  include ReportableMixin

  SVC_TYPES = {
    # Type     Display
    ""    => "",
    "1"   => _("Kernel Driver"),
    "2"   => _("File System Driver"),
    "4"   => _("Service Adapter"),
    "8"   => _("Recognizer Driver"),
    "16"  => _("Win32 Own Process"),
    "32"  => _("Win32 Shared Process"),
    "256" => _("Interactive"),
    "272" => _("Win32 Own Process, Interactive"),
    "288" => _("Win32 Shared Process, Interactive"),
  }

  START_TYPES = {
    # Type     Display
    ""  => "",
    "0" => _("Boot Start"),
    "1" => _("System Start"),
    "2" => _("Automatic"),
    "3" => _("Manual"),
    "4" => _("Disabled")
  }

  def start
    s = self['start']
    START_TYPES[s] || s
  end

  def svc_type
    svc = self['svc_type']
    SVC_TYPES[svc] || svc
  end

  def self.running_systemd_services_condition
    arel_table[:systemd_active].eq('active').and(arel_table[:systemd_sub].eq('running'))
  end

  def self.failed_systemd_services_condition
    arel_table[:systemd_active].eq('failed').or(arel_table[:systemd_sub].eq('failed'))
  end

  def self.host_service_group_condition(host_service_group_id)
    arel_table[:host_service_group_id].eq(host_service_group_id)
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
