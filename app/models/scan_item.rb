class ScanItem < ApplicationRecord
  include_concern "Seeding"

  serialize :definition
  acts_as_miq_set_member
  include UuidMixin

  def self.get_default_profiles
    get_profile('default')
  end

  def self.get_profile(set_name)
    profiles = []
    si = ScanItemSet.find_by(:name => set_name)
    if si
      y = si.attributes
      y["definition"] = []
      si.members.each do |m|
        y["definition"] << m.attributes
      end
      profiles << y
    end
    profiles
  end

  def self.add_elements(vm, xmlNode)
    el = xmlNode.root
    return nil unless MiqXml.isXmlElement?(el)
    return nil unless el.name == 'scan_profiles'

    el.each_element do |profile|
      guid = profile.attributes['guid']
      sis = ScanItemSet.find_by(:guid => guid)
      if sis.nil?
        _log.warn("Unable to find ScanItemSet [guid: #{guid}] in the database.")
        next
      end

      profile.each_element do |e|
        item_type = e.attributes['item_type']
        guid = e.attributes['guid']

        si = ScanItem.find_by(:guid => guid)
        if si.nil?
          _log.warn("Unable to find ScanItem [guid: #{guid} type: #{item_type}] in the database.")
          next
        end

        case item_type
        when 'file'
          Filesystem.add_elements(sis, si, vm, e)
        when 'registry'
          RegistryItem.add_elements(sis, si, vm, e)
        when 'category'
          _log.debug("Skipping ScanItem [guid: #{guid} type: #{item_type}] as it is not expected in the data.")
        when 'nteventlog'
          EventLog.add_elements(vm, e)
        else
          _log.debug("Unknown ScanItem type [#{item_type}]")
        end
      end
    end
  end
end
