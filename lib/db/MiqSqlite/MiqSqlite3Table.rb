require 'ostruct'
require 'enumerator'

require 'binary_struct'
require_relative 'MiqSqlite3Util'
require_relative 'MiqSqlite3Page'
require_relative 'MiqSqlite3Cell'

module MiqSqlite3DB
  class MiqSqlite3Table
    
    def self.table_names(db)
      names = Array.new
      MiqSqlite3Table.each(db) { |table| 
        names << table.name if 'table' == table.type
      }
      return names
    end
    
    def self.index_names(db)
      names = Array.new
      MiqSqlite3Table.each(db) { |table| 
        names << table.name if 'index' == table.type
      }
      return names
    end
    
    def self.getTable(db, name)
      MiqSqlite3Table.each(db) { |table|
        return table if name == table.name
      }
      return nil
  	end

    def self.each(db)
      root_page = MiqSqlite3Page.getPage(db, 1)
  
      root_page.each_child { |child|
        page = MiqSqlite3Page.getPage(db, child)
        page.each_cell { |cell|
          yield MiqSqlite3Table.new(db, child, cell)
        }
      }
    end
    
    #####################################
    ## Instance Methods
    #####################################

		attr_reader :name, :type

		def initialize(db, pagenum, cell)
			@pagenum = pagenum
			@db      = db
      @fields  = cell.fields
      @type    = @fields[0]['data']
      @name    = @fields[1]['data']
      @desc    = @fields[2]['data']
      @data    = @fields[3]['data']
      @sql     = @fields[4]['data']
		  @columns = nil
		  decodeSchema
		end
		
		
		def decodeSchema
		  return if @type != "table" || @name[0..6] == "sqlite_"  # Names beginning with sqlite_ are internal to engine
		  @columns = Array.new
		  sql = @sql.gsub(/[\n\r]/, "")
		  re1 = /\s*CREATE\s+TABLE\s+(\w+)\s*\((.*)\)\s*/
		  m = re1.match(sql)
		  tname = m[1].to_s.chomp
		  raise "Inconsistent Table Name" if tname != @name
		  cols  = m[2].to_s

      cols.split(",").each { |c|
        words = c.split
        defn = Hash.new
        defn['name'] = words[0]
        defn['type'] = words[1].downcase
        defn['type'] = "key" if words[2] && words[2].upcase == "PRIMARY"
        if defn['type'] == "key"
          @key = defn['name']
        else
          @columns << defn
        end
      }
	  end
		
		def each_row
		  MiqSqlite3Page.getPage(@db, @data).leaves { |leaf|
		    leaf.each_cell { |cell|
		      row = Hash.new
		      row[@key] = cell.key if @key
		      i = @key ? 1 : 0
		      each_column { |col|
		        row[col['name']] = cell.fields[i]['data']
		        i += 1
		      }
		      yield row
		    }
		  }
	  end
	  
	  def each_column
		  @columns.each { |col| yield col }
    end

    
		def dump
		  puts "================="
		  puts "Page:                            #{@pagenum}"
		  puts "Length:                          #{@len}"
		  puts "Type:                            #{@type}"
		  puts "Name:                            #{@name}"
		  puts "Description:                     #{@desc}"
		  puts "Data Begins on Page:             #{@data}"
		  puts "SQL:                             #{@sql}"
		  puts "Key:                             #{@key}"  if @key
		  if @columns
  	    for i in 1..@columns.size
          puts "Column #{i}:                        #{@columns[i-1]['name']} => #{@columns[i-1]['type']}"
        end
      end
	  end

  end

end
