# encoding: US-ASCII

require 'VolumeManager/LVM'

if __FILE__ == $0
  md = IO.read("lvmt2_metadata")
  parser = Lvm2MdParser.new(md, nil)
  puts "Parsing metadata for volume group: #{parser.vgName}"
  vg = parser.parse
  vg.dump

  vg.logicalVolumes.each_value do |lv|
    puts "***** LV: #{lv.lvName} start *****"
    parser.dumpVg(lv.vgObj)
    puts "***** LV: #{lv.lvName} end *****"
  end
end
