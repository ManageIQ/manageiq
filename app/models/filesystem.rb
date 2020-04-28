require 'metadata/linux/LinuxUtils'

class Filesystem < ApplicationRecord
  belongs_to :resource, :polymorphic => true
  belongs_to :miq_set    # ScanItemSet
  belongs_to :scan_item
  belongs_to :host_service_group

  has_many :custom_attributes, :as => :resource, :dependent => :destroy
  has_one :binary_blob, :as => :resource, :dependent => :destroy

  include FilterableMixin
  virtual_column :contents,           :type => :string,  :uses => {:binary_blob => :binary_blob_parts}
  virtual_column :contents_available, :type => :boolean, :uses => :binary_blob

  scope :host_service_group_filesystems, ->(host_service_group_id) { where(:host_service_group_id => host_service_group_id) }

  UTF_16BE_BOM = [254, 255].freeze
  UTF_16LE_BOM = [255, 254].freeze

  def self.add_elements(miq_set, scan_item, parent, xmlNode)
    options = {}
    options[:miq_set_id]   = miq_set.id   unless miq_set.nil?
    options[:scan_item_id] = scan_item.id unless scan_item.nil?

    hashes = xml_to_hashes(xmlNode, options)
    EmsRefresh.save_filesystems_inventory(parent, hashes) if hashes
  end

  def self.xml_to_hashes(xmlNode, options = {})
    return nil unless MiqXml.isXmlElement?(xmlNode)

    results = []
    xmlNode.each_element('filesystem') do |el|
      results += process_sub_xml(el, el.attributes['base_path'].to_s, options)
    end
    results
  end

  def self.process_sub_xml(xmlNode, path, options = {})
    results = []
    xmlNode.each_element do |e|
      if e.name == 'dir'
        results += process_sub_xml(e, path + '\\' + e.attributes['name'], options)
      elsif e.name == 'file'
        nh = e.attributes.to_h

        nh[:base_name] = nh[:name]
        nh[:name] = nh[:fqname]
        nh[:rsc_type] = e.name
        nh.delete(:fqname)
        nh[:mtime] = Time.parse(nh[:mtime])
        nh[:atime] = Time.parse(nh[:atime])
        nh[:ctime] = Time.parse(nh[:ctime])

        nh.merge!(options)

        verinfo = e.elements['versioninfo']
        if verinfo
          vh = verinfo.attributes.to_h
          nh[:product_version_header] = vh[:PRODUCTVERSION_HEADER]
          nh[:product_version] = vh[:ProductVersion]
          nh[:file_version_header] = vh[:FILEVERSION_HEADER]
          nh[:file_version] = vh[:FileVersion]
        end

        nh[:contents] = nil
        file_contents = e.elements['contents']
        unless file_contents.nil?
          ch = file_contents.attributes.to_h
          nh[:contents] = file_contents.text
          if ch[:encoded] == 'true'
            compressed = ch[:compressed] == 'true'
            nh[:contents] = MIQEncode.decode(nh[:contents], compressed)
          end
        end

        results << nh
      end
    end
    results
  end

  def image_name
    ext = base_name && File.extname(base_name)
    unless ext.nil?
      ext.sub!(".", "")
      ext.downcase!
      return ext if %w(dll exe log txt xml ini doc pdf zip).include?(ext)
    end
    "unknown"
  end

  def contents
    binary_blob.try(:binary)
  end

  def contents=(val)
    if val.nil?
      self.binary_blob = nil
    else
      self.binary_blob ||= BinaryBlob.new(:name => "contents")
      self.binary_blob.binary = val
    end
  end

  def has_contents?
    !self.binary_blob.nil?
  end
  alias_method :contents_available, :has_contents?

  def contents_displayable?
    return false if name.nil?
    # We will display max 20k characters in the UI textarea
    return false if size > 20_000
    mime_type = MIME::Types.of(name).first
    return has_contents? && contents.force_encoding("UTF-8").ascii_only? if mime_type.nil?
    !mime_type.binary?
  end

  def displayable_contents
    return nil unless has_contents?
    bom = contents.byteslice(0, 2).bytes
    if contents_displayable? && (bom == UTF_16BE_BOM || bom == UTF_16LE_BOM)
      contents.force_encoding('UTF-16').encode('UTF-8')
    else
      contents
    end
  end

  [
    [:suid_bit,    04000],
    [:sgid_bit,    02000],
    [:sticky_bit,  01000],
    [:owner_read,  00400],
    [:owner_write, 00200],
    [:owner_exec,  00100],
    [:group_read,  00040],
    [:group_write, 00020],
    [:group_exec,  00010],
    [:other_read,  00004],
    [:other_write, 00002],
    [:other_exec,  00001],
  ].each do |m, o|
    define_method("permission_#{m}?") do
      return permissions && permissions.to_i(8) & o != 0
    end
  end

  def permissions_str
    MiqLinux::Utils.octal_to_permissions(permissions)
  end
end
