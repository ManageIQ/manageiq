class Volume < ApplicationRecord
  belongs_to :hardware
  has_many :partitions, lambda { |_|
    p = Partition.quoted_table_name
    v = Volume.quoted_table_name
    Partition.select("DISTINCT #{p}.*")
      .joins("JOIN #{v} ON #{v}.hardware_id = #{p}.hardware_id AND #{v}.volume_group = #{p}.volume_group")
      .where("#{v}.id" => id).to_sql
  }, :foreign_key => :volume_group

  virtual_column :free_space_percent, :type => :float
  virtual_column :used_space_percent, :type => :float

  PHYSICAL_VOLUME_GROUP = '***physical_'

  def volume_group
    # Override volume_group getter to prevent the special physical linkage from coming through
    vg = read_attribute(:volume_group)
    return nil if vg.respond_to?(:starts_with?) && vg.starts_with?(PHYSICAL_VOLUME_GROUP)
    vg
  end

  def free_space_percent
    return nil if size.nil? || size == 0 || free_space.nil?
    Float(free_space) / size * 100
  end

  def used_space_percent
    return nil if size.nil? || size == 0 || used_space.nil?
    Float(used_space) / size * 100
  end

  def self.add_elements(parent, xmlNode)
    hashes = xml_to_hashes(parent, xmlNode)
    return if hashes.nil?

    deletes = {}
    deletes[:partitions] = parent.hardware.partitions.order(:id).pluck(:id, :name)
    deletes[:volumes] = parent.hardware.volumes.order(:id).pluck(:id, :name)

    new_partitions = []
    new_volumes = []
    dup_partitions = {}
    dup_volumes = {}

    hashes.each do |nh|
      nhp = nh[:partition]
      unless nhp.nil?
        name = nhp[:name]
        found = parent.hardware.partitions.where(:name => name).order(:id)

        # Handle duplicate partition names (Generally only in the case of Windows with blank partition names)
        if found.length > 1
          dup_partitions[name] = found.collect(&:id) if dup_partitions[name].nil?
          found_id = dup_partitions[name].shift
          found = found.detect { |f| f.id == found_id }
        else
          found = found[0]
        end
        found.nil? ? new_partitions << nhp : found.update(nhp)

        deletes[:partitions].each_with_index do |ele, i|
          if ele[1] == name
            deletes[:partitions].delete_at(i)
            break
          end
        end
      end

      nhv = nh[:volume]
      unless nhv.nil?
        name = nhv[:name]
        found = parent.hardware.volumes.where(:name => name).order(:id)

        # Handle duplicate volume names (Generally only in the case of Windows with blank volume names)
        if found.length > 1
          dup_volumes[name] = found.collect(&:id) if dup_volumes[name].nil?
          found_id = dup_volumes[name].shift
          found = found.detect { |f| f.id == found_id }
        else
          found = found[0]
        end
        found.nil? ? new_volumes << nhv : found.update(nhv)

        deletes[:volumes].each_with_index do |ele, i|
          if ele[1] == name
            deletes[:volumes].delete_at(i)
            break
          end
        end
      end
    end

    parent.hardware.partitions.build(new_partitions)
    parent.hardware.volumes.build(new_volumes)
    # Delete the IDs that correspond to the remaining names in the current list.
    _log.info("Partition deletes: #{deletes[:partitions].inspect}") unless deletes[:partitions].empty?
    Partition.delete(deletes[:partitions].transpose[0])
    _log.info("Volume deletes: #{deletes[:volumes].inspect}") unless deletes[:volumes].empty?
    Volume.delete(deletes[:volumes].transpose[0])
  end

  def self.xml_to_hashes(parent, xmlNode)
    result = []

    # Handle the physical volumes
    xmlNode.elements[1].each_element do |e|
      nh = {}

      nh[:partition] = nhp = e.attributes.to_h
      nhp.delete(:disk_type)
      nhp[:volume_group] = "#{PHYSICAL_VOLUME_GROUP}#{nhp[:controller]}"

      # Find the disk-partition linkage
      disk = find_disk_by_controller(parent, nhp[:controller])
      nhp[:disk_id] = disk.id unless disk.nil?

      nh[:volume] = nhv = {}
      nhv[:typ] = 'physical'
      nhv[:name] = nhp[:name]
      nhv[:size] = nhp[:size]
      nhv[:volume_group] = nhp[:volume_group]
      nhv[:filesystem] = nhp.delete(:filesystem)
      nhv[:used_space] = nhp.delete(:used_space)
      nhv[:free_space] = nhp.delete(:free_space)

      result << nh
    end

    # Handle the hidden volumes
    xmlNode.elements[2].each_element do |e|
      nh = {}
      nh[:partition] = nhp = e.attributes.to_h
      nhp.delete(:disk_type)

      # Find the disk-partition linkage
      disk = find_disk_by_controller(parent, nhp[:controller])
      nhp[:disk_id] = disk.id unless disk.nil?

      result << nh
    end

    # Handle the logical volumes
    xmlNode.elements[3].each_element do |e|
      nh = {}
      nh[:volume] = nhv = e.attributes.to_h
      nhv.delete(:type)
      nhv.delete(:volume_name)
      nhv.delete(:drive_hint)
      nhv[:typ] = 'logical'
      result << nh
    end

    result
  end

  def self.find_disk_by_controller(parent, controller)
    return parent.hardware.disks.find_by(:controller_type => $1, :location => $2) if controller =~ /^([^0-9]+)([0-9]:[0-9]):[0-9]$/
    nil
  end
end
