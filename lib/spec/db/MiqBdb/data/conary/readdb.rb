#  readdb.rb  -  This script will read a Conary database
#  and list the pages.
#
#  Author:  Steven Oliphant
#           Stonecap Enterprises
#
#  This software is copyrighted 2007 All rights reserved
#  ManageIQ
#  1 International Boulevard
#  Mahwah, NJ   07495         
#

# Convert Hex binary to an integer

def BinToInt(str)
  hnum = str.unpack('H*')
  hlen = hnum.length
  num = 0
  hnum[0].each_byte { |digit|
    value = case digit.chr
            when "0"
              0
            when "1"
              1
            when "2"
              2
            when "3"
              3
            when "4"
              4
            when "5"
              5
            when "6"
              6
            when "7"
              7
            when "8"
              8
            when "9"
              9
            when "a"
              10
            when "b"
              11
            when "c"
              12
            when "d"
              13
            when "e"
              14
            when "f"
              15
            end
    num = (num * 16) + value
  } 
  return num  
end

# convert a var[1-9] to an integer

def VarToInt(buffer, ptr)
  varvalue = 0
  cont = 1
  cnt = 0
  puts "ptr: " + ptr.to_s
  while cont > 0
    
    var = buffer[ptr + cnt]
    puts "var: " + var.to_s
    if var[7] == 1 then
      puts "Bit 8 set"
      var = var & 127
      cnt += 1
    else
      puts "Bit 8 not set"
      cont = 0
    end
    varvalue = varvalue << 7
    varvalue = varvalue | var
    puts "varvalue: " + varvalue.to_s
    if cnt > 8 then puts "variable greater than 9 bytes" end
  end
  # adjust byte count
  cnt += 1
  puts "varcnt: " + cnt.to_s
  return varvalue, cnt
end

if ARGV.length == 0
  puts "No database name given"
  exit
end

begin
  fn = ARGV[0]
  fh = File.open(fn, "rb")
rescue
  puts fn+" cannot be opened"
  exit
end

pagesize = 1024     # default page size
filehdrsz = 100     # File header size
pghdrsz = 12        # max size - can be 8 or 12 bytes
hdrstrsz = 16       # Header string size

# Page header flags

intkey =  0         # bit 1
zerodata = 1        # bit 2
leafdata = 2        # bit 4
leaf = 3            # bit 8

# page header offsets

flagoffset        = 0
flagsz            = 1
nbrcellsoffset    = 3
nbrcellssz        = 2
firstcelloffset   = 5
firstcellsz       = 2
rightchildoffset  = 8
rightchildsz      = 4

# cell pointer data

cellptrsz  = 2

# cell data

leftchildsz = 4


# read first page - contains the File Header

begin 
  page = fh.read(pagesize)
  puts "File Header Data"
  puts "File header string: " + page[0..hdrstrsz-1]
  spgsz = page[hdrstrsz,2]
  hpgsz =  BinToInt(spgsz)
  puts "Page size: " + hpgsz.to_s
  # check page size
  if hpgsz != pagesize then 
    # page size is different from default - reread first page
    pagesize = hpgsz  
    fh.rewind
    fhdr = fh.read(pagesize)
  end 
rescue => err 
  puts "Page 1 read failed for database: "+fn
  puts "error: "+err
  exit  
end

# process the first page header

phdrptr = filehdrsz

testcnt = 10
offset = 0
testcnt.times { |testctr|
  puts "Block: " + testctr.to_s
  printf "Offset: 0x%08x\n", offset.to_s
  #file header only in Block 0
  if testctr > 0 then phdrptr = 0 end
flags = page[phdrptr]
puts "Flags: " + flags.to_s

if flags[intkey] == 1 then 
  puts "intkey is set"
  intkeyfg = 1
else
  intkeyfg = 0
end

if flags[zerodata] == 1 then
  puts "zerodata is set"
  zerodatafg = 1
else
  zerodatafg = 0
end

if flags[leafdata] == 1 then
  puts "leafdata is set"
  leafdatafg = 1
else
  leafdatafg = 0
end

if flags[leaf] == 1 then 
  puts "leaf is set"
  leaffg = 1
else 
  leaffg = 0
end

cellcnt = BinToInt(page[phdrptr+nbrcellsoffset, nbrcellssz])
puts "Cell count: " + cellcnt.to_s

celloffset = BinToInt(page[phdrptr+firstcelloffset, firstcellsz])
puts "First cell offset: " + celloffset.to_s
printf "Offset: 0x%04x\n", celloffset.to_s

# Page header is 12 bytes when leaf is not set

if leaffg == 0 then
  rightchild = BinToInt(page[phdrptr+rightchildoffset, rightchildsz])
  puts "Right Child: " + rightchild.to_s
  firstdataptr = pghdrsz
else
  firstdataptr = pghdrsz - rightchildsz
end
puts "First data offset: " + firstdataptr.to_s

# Get the cell pointers

cellptr = Array.new 

cellcnt.times { |i| 
  cellp = page[(phdrptr + firstdataptr + (cellptrsz * i)), cellptrsz]
  puts cellp.unpack('H*')
  cellptr[i] = BinToInt(cellp)
  puts "Cell pointer: " + cellptr[i].to_s
}

#look at each cell

cellptr.each { |ptr|
  if leaffg ==  0 then
    leftchild = BinToInt(page[ptr, leftchildsz])
    puts "Left Child: " + leftchild.to_s
    datainfo = VarToInt(page, (ptr + leftchildsz))
    dataoffset = ptr + leftchildsz 
  else
    datainfo = VarToInt(page, ptr)
    dataoffset = ptr
  end
  databytecnt = datainfo[0]
  puts "databytecnt: " + databytecnt.to_s
  puts "datainfo 1 : " + datainfo[1].to_s
  dataoffset = dataoffset + datainfo[1]

  if intkeyfg > 0 then
    printf "Key: 0x%02x\n", databytecnt.to_s
  else
    printf "Data size: 0x%02x\n", databytecnt.to_s
    puts "data: " + page[dataoffset, databytecnt]  
  end
}
page = fh.read(pagesize)
offset += pagesize
}
  
# close file when done
fh.close
