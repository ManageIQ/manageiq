require 'ruby-plsql'

module MiqOracle
  def self.test_connection(database, username, password)
    msg_header = "MIQ(MiqOracle.test_connection)"
    msg_target = "user: [#{username}], database: [#{database}]"
    msg = ""
    msg_level = :info

    begin
      OCI8.new(username, password, database).exec("SELECT 1 FROM dual") do |r|
        if r && r.length == 1 && r[0] == 1
          msg = "Connection successful for #{msg_target}."
          msg_level = :info
        else
          msg = "Connection successful for #{msg_target}, but results unexpected."
          msg_level = :warn
        end
      end
    rescue OCIError => err
      err_type = nil
      if err.message =~ /ORA-(\d+)/
        err_type = case $1
        when '01017' then "Invalid username/password"
        when '12560' then "Invalid hostname"
        when '12170' then "Possible invalid hostname or server not running Oracle service"
        when '12541' then "Invalid port number"
        when '12514' then "Invalid instance name"
        end
      end
      err_type = "Oracle error" if err_type.nil?

      msg = "Connection failed for #{msg_target} - #{err_type}:\n#{err.class.name}: #{err.message}"
      msg_level = :error
    rescue Exception => err
      msg = "Connection failed for #{msg_target}:\n#{err.class.name}: #{err.message}"
      msg_level = :error
    end

    puts msg
    $log.send(msg_level, "#{msg_header} #{msg}") if $log
    return msg_level == :info
  end

  def self.exec_stored_procedure(database, username, password, procedure, *params)
    log_msg = "MIQ(MiqOracle.exec_stored_procedure) Executing stored procedure: [#{procedure}], user: [#{username}], database: [#{database}]" if $log
    begin
      $log.info "#{log_msg}..." if $log
      plsql.connection = OCI8.new(username, password, database)
      ret = plsql.send(procedure, *params)
      $log.info "#{log_msg}...Complete" if $log
      return ret
    ensure
      plsql.logoff rescue nil
    end
  end
end
