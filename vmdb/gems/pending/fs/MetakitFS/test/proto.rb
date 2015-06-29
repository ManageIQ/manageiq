require 'rubygems'
require 'mk4rb'

require "../MetakitFS"

TYPE_FILE = 1
TYPE_DIR  = 2

TEST_DATA = "Hello World\n"

begin
    pPath = Metakit::StringProp.new "fpath"
    pType, pSize = Metakit::IntProp[:ftype, :fsize]
    pData = Metakit::BytesProp.new "fdata"

    Metakit::Storage.open("myfile.dat", 1) do |storage|
        puts "Description: #{storage.description}"
        vData   = storage.get_as MetakitFS::MK_FENTRY
        vSec    = storage.get_as MetakitFS::MK_HASHVW
        vFentry = vData.hash(vSec, 1)

        row = Metakit::Row.new

        pPath.set row, "/etc/passwd"
        pType.set row, TYPE_FILE
        pSize.set row, 0
        data = Metakit::Bytes.new("", 0)
        pData.set row, data
        vFentry.add row
    
        pPath.set row, "/etc/hosts"
        vFentry.add row

        storage.commit
    end # Metakit::Storage.open

    findrow = Metakit::Row.new
    
    Metakit::Storage.open("myfile.dat", 1) do |storage|
        puts "Description: #{storage.description}"
        raise "myfile.dat is not a MetakitFS" if storage.description != "#{MetakitFS::MK_FENTRY},#{MetakitFS::MK_HASHVW}"
        vData   = storage.get_as MetakitFS::MK_FENTRY
        vSec    = storage.get_as MetakitFS::MK_HASHVW
        vFentry = vData.hash(vSec, 1)
        
        (1..100).each do |n|
            pPath.set findrow, "/etc/hosts"
            idxsearch = vFentry.find(findrow, 0)
            puts "idxsearch = #{idxsearch}"
            raise "File not found: /etc/hosts" if idxsearch < 0
                    
            r = vFentry[idxsearch]
            puts "row = #{r}"
    
            puts "Path: #{pPath.get(r)}"
            dataRef = pData.ref(r)
            dsize = pSize.get(r)
            puts "Data size: #{dsize}"
    
            ds = "Line: #{n}\n"
            data = Metakit::Bytes.new(ds, ds.length)
            dataRef.modify(data, dsize, data.size)
            # dataRef.modify(data, 8, 0) if n == 99
            pSize.set(r, dsize + data.size)
                
            storage.commit
        end
        
        puts
        puts "****************"
        puts
        
        pPath.set findrow, "/etc/hosts"
        idxsearch = vFentry.find(findrow, 0)
        raise "File not found: /etc/hosts" if idxsearch < 0
        
        r = vFentry[idxsearch]
        
        puts "Path: #{pPath.get(r)}"
        puts "idxsearch = #{idxsearch}"
        puts "row = #{r}"
        dataRef = pData.ref(r)
        dsize = pSize.get(r)
        puts "Data size: #{dsize}"
        
        rs = 100
        rp = 0
        while true
            rb = dataRef.access(rp, rs)
            break if rb.size == 0
            print rb.contents
            rp += rs
        end
    end
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
end
