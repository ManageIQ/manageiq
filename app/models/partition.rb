class Partition < ApplicationRecord
  belongs_to :disk
  belongs_to :hardware
  has_many :volumes,
           lambda { |_|
             p = Partition.quoted_table_name
             v = Volume.quoted_table_name
             Volume.select("DISTINCT #{v}.*")
               .joins("JOIN #{p} ON #{v}.hardware_id = #{p}.hardware_id AND #{v}.volume_group = #{p}.volume_group")
               .where("#{p}.id" => id)
           }, :foreign_key => :volume_group

  virtual_column :aligned, :type => :boolean

  def volume_group
    # Override volume_group getter to prevent the special physical linkage from coming through
    vg = read_attribute(:volume_group)
    return nil if vg.respond_to?(:starts_with?) && vg.starts_with?(Volume::PHYSICAL_VOLUME_GROUP)
    vg
  end

  # Derived from linux fdisk "list known partition types"
  # More info at http://www.win.tue.nl/~aeb/partitions/partition_types-1.html
  PARTITION_TYPE_NAMES = {
    0x00 => "Empty",
    0x01 => "FAT12",
    0x02 => "XENIX root",
    0x03 => "XENIX usr",
    0x04 => "FAT16 <32M",
    0x05 => "Extended",
    0x06 => "FAT16",
    0x07 => "HPFS/NTFS",
    0x08 => "AIX",
    0x09 => "AIX bootable",
    0x0a => "OS/2 Boot Manager",
    0x0b => "W95 FAT32",
    0x0c => "W95 FAT32 (LBA)",
    0x0e => "W95 FAT16 (LBA)",
    0x0f => "W95 Ext'd (LBA)",
    0x10 => "OPUS",
    0x11 => "Hidden FAT12",
    0x12 => "Compaq diagnostic",
    0x14 => "Hidden FAT16 <32M",
    0x16 => "Hidden FAT16",
    0x17 => "Hidden HPFS/NTFS",
    0x18 => "AST SmartSleep",
    0x1b => "Hidden W95 FAT32",
    0x1c => "Hidden W95 FAT32 (LBA)",
    0x1e => "Hidden W95 FAT16 (LBA)",
    0x24 => "NEC DOS",
    0x39 => "Plan 9",
    0x3c => "PartitionMagic",
    0x40 => "Venix 80286",
    0x41 => "PPC PReP Boot",
    0x42 => "SFS",
    0x4d => "QNX4.x",
    0x4e => "QNX4.x 2nd part",
    0x4f => "QNX4.x 3rd part",
    0x50 => "OnTrack DM",
    0x51 => "OnTrack DM6 Aux1",
    0x52 => "CP/M",
    0x53 => "OnTrack DM6 Aux3",
    0x54 => "OnTrackDM6",
    0x55 => "EZ-Drive",
    0x56 => "Golden Bow",
    0x5c => "Priam Edisk",
    0x61 => "SpeedStor",
    0x63 => "GNU HURD or System V",
    0x64 => "Novell Netware 286",
    0x65 => "Novell Netware 386",
    0x70 => "DiskSecure MultiBoot",
    0x75 => "PC/IX",
    0x80 => "Old MINIX",
    0x81 => "MINIX / old Linux",
    0x82 => "Linux swap / Solaris",
    0x83 => "Linux",
    0x84 => "OS/2 hidden C:",
    0x85 => "Linux extended",
    0x86 => "NTFS volume set",
    0x87 => "NTFS volume set",
    0x88 => "Linux plaintext",
    0x8e => "Linux LVM",
    0x93 => "Amoeba",
    0x94 => "Amoeba BBT",
    0x9f => "BSD/OS",
    0xa0 => "IBM Thinkpad hibernation",
    0xa5 => "FreeBSD",
    0xa6 => "OpenBSD",
    0xa7 => "NeXTSTEP",
    0xa8 => "Darwin UFS",
    0xa9 => "NetBSD",
    0xab => "Darwin boot",
    0xb7 => "BSDI fs",
    0xb8 => "BSDI swap",
    0xbb => "Boot Wizard hidden",
    0xbe => "Solaris boot",
    0xbf => "Solaris",
    0xc1 => "DRDOS/sec (FAT-12)",
    0xc4 => "DRDOS/sec (FAT-16 <32M)",
    0xc6 => "DRDOS/sec (FAT-16)",
    0xc7 => "Syrinx",
    0xda => "Non-FS Data",
    0xdb => "CP/M / CTOS",
    0xde => "Dell Utility",
    0xdf => "BootIt",
    0xe1 => "DOS access",
    0xe3 => "DOS R/O",
    0xe4 => "SpeedStor",
    0xeb => "BeOS fs",
    0xee => "EFI GPT",
    0xef => "EFI (FAT-12/16/32)",
    0xf0 => "Linux/PA-RISC boot loader",
    0xf1 => "SpeedStor",
    0xf2 => "DOS secondary",
    0xfb => "VMware File System",
    0xfc => "VMware Swap",
    0xfd => "Linux raid auto",
    0xfe => "LANstep",
    0xff => "BBT",
  }

  UNKNOWN_PARTITION_TYPE = "UNKNOWN".freeze

  def self.partition_type_name(partition_type)
    return PARTITION_TYPE_NAMES[partition_type] if PARTITION_TYPE_NAMES.key?(partition_type)
    UNKNOWN_PARTITION_TYPE
  end

  def partition_type_name
    self.class.partition_type_name(partition_type)
  end

  def alignment_boundary
    # TODO: Base alignment on logical block size of storage
    ::Settings.storage.alignment.boundary.to_i_with_method
  end

  def aligned?
    return nil if start_address.nil?

    # We check all of physical volumes of the VM. This Includes visible and hidden volumes, but excludes logical volumes.
    # The alignment of hidden volumes affects the performance of the logical volumes that are based on them.
    start_address % alignment_boundary == 0
  end
  alias_method :aligned, :aligned?
end
