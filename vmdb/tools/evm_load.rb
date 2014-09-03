class EvmLoad
  # zipfile can be a zipfile or a directory
  def run(zipfile)
    $stdout.sync = true

    each_file_in_zip(zipfile) do |yml_file_name|
      file_records = YAML.load_file(yml_file_name)
      file_record_count = file_records.size

      model = determine_model(file_records, yml_file_name)
      db_record_count = model.count

      log_pre_info(yml_file_name, file_record_count, db_record_count)
      truncate, load = determine_load(file_record_count, db_record_count)

      truncate_model(model) if truncate
      file_records = partial_records(file_records)
      load_records(file_records) if load
      reset_sequence(model) if load

      log_post_info(model)
    end
  end

  private

  def each_file_in_zip(zipfile, &block)
    if File.directory?(zipfile)
      Dir.chdir(zipfile)
      each_file_in_directory(&block)
    else
      require 'tempfile'
      Dir.mktmpdir('evm_dump_files') do |tmp|
        Dir.chdir(tmp)
        system("unzip #{zipfile}")
        each_file_in_directory(&block)
      end
    end
  end

  def each_file_in_directory(&block)
    yml_files = Dir["*.yml"]
    @yml_file_max_length = yml_files.collect(&:length).max
    yml_files.each(&block)
  end

  def log_pre_info(yml_file_name, file_record_count, db_record_count)
    printf "%-#{@yml_file_max_length}s :  file %5d db %5d", yml_file_name, file_record_count, db_record_count
  end

  def determine_load(file_record_count, db_record_count)
    truncate, load = false, true
    if file_record_count == 0
      puts "no records in the file"
      load = false
      truncate = ask("truncate database", 'y')
    elsif db_record_count > 0
      puts "records exist in the database"
      # do we want to load this model anyway?
      load = ask("load anyway", 'n')
      # only truncate if we are loading
      truncate = load && ask("truncate database", 'y')
    end
    [truncate, load]
  end

  def truncate_model(model)
    puts "truncating #{model.name}"
    model.destroy_all
  end

  # only load a partial set of file_records
  # NOTE: there are duplicate records in the yaml file.
  def partial_records(file_records)
    previous_file_record_count = file_records.size
    file_records = file_records.uniq
    if previous_file_record_count == file_records.size
      puts "loading #{file_records.size} records"
    else
      puts "loading #{file_records.size}/#{previous_file_record_count} records"
    end
    file_records
  end

  def load_records(file_records)
    file_records.each do |obj|
      begin
        if !obj.valid?
          puts "\n#{obj.errors.messages.join(",")}: #{obj.inspect}\n"
        else
          print "."
          # tell active record this record is not already in the database
          obj.instance_variable_set("@new_record", true)
          # tell active record to actually save to the database
          obj.save!
        end
      rescue => e
        puts "\nfailed #{e.message} #{obj.inspect}\n"
      end
    end
  end

  def reset_sequence(model)
    model.connection.reset_pk_sequence!(model.table_name)
  end

  def log_post_info(model)
    puts "\n#{model.name}.count == #{model.count}"
  end

  private

  def ask(prompt, default = 'n')
    print prompt, "? (#{upcase_default('y', default)}/#{upcase_default('n', default)}): "
    s = $stdin.gets.chomp.downcase[0]
    (s || default) == "y"
  end

  def upcase_default(option, default)
    option == default ? option.upcase : option
  end

  def determine_model(file_records, yml_file_name)
    file_records.first.try(:class) || model_from_filename(yml_file_name)
  end

  def model_from_filename(filename)
    Object.const_get(filename.split('.').first.camelize)
  end
end

zipfile = File.expand_path(File.join(Dir.pwd, ARGV[0] || "evm_dump.zip"))
EvmLoad.new.run(zipfile)
