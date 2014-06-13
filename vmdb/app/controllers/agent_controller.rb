$:.push("#{File.dirname(__FILE__)}/../../../lib/metadata/linux")
require 'miq-xml'

class AgentController < ApplicationController
  def get
    proxy_id = sanitize_id(params[:id])
    task_id  = sanitize_id(params[:task_id])
    raise "invalid proxy id [#{params[:id].inspect}]" if proxy_id.nil?

    task = MiqTask.where(:id => task_id).first unless task_id.nil?

    $log.info "MIQ(agent-get): Request agent update for Proxy id [#{proxy_id}] and Product Update id [#{params[:product_update_id].inspect}]"
    task.update_status("Active", "Ok", "Starting SmartProxy download") if task
    proxy = MiqProxy.where(:id => proxy_id).first
    if proxy.nil?
      task.update_status("Active", "Warn", "SmartProxy download failed to find Proxy with id [#{proxy_id}]") if task
      raise "unable to find Proxy with id [#{proxy_id}]"
    end

    update = ProductUpdate.where(:id => params[:product_update_id].to_i).first
    if update.nil?
      task.update_status("Active", "Warn", "SmartProxy update failed to find Product Update with id [#{proxy_id}]") if task
      raise "unable to find Product Update with id [#{params[:product_update_id].inspect}]"
    end

    file = update.file_from_db(proxy)
    unless File.exists?(file)
      task.update_status("Active", "Warn", "No media found for Proxy #{proxy.id} and version #{update.build}") if task
      raise "no media found for proxy\"#{proxy.id}\" and version\"#{update.build}\""
    end

    headers["md5"]      = update.md5
    headers["filename"] = File.basename(file)
    headers["status"]   = "200"

    module_desc = "#{update.component} #{update.version}.#{update.build}"
    $log.info "MIQ(agent-get): Send file: #{file}"
    task.update_status("Active", "Ok", "Download starting for #{module_desc}") if task
    disable_client_cache
    send_file(file)
    task.update_status("Active", "Ok", "Download completed for #{module_desc}") if task
  end

  def log
    host_guid = sanitize_guid(params[:id])
    task_id   = sanitize_id(params[:taskid])
    raise "invalid host guid [#{params["id"].inspect}]" if host_guid.nil?

    $log.info "MIQ(agent-log): Posting log for proxy: [#{host_guid}], " +
              "file: [#{params['filename'].inspect}]. [#{params['current'].inspect}] of " +
              "[#{params['total'].inspect}] uploads. Task: [#{params[:taskid].inspect}]. " +
              "Completed: [#{params['completed'].inspect}]"

    host = Host.find_by_guid(host_guid)
    raise "unable to find host with guid [#{host_guid}]" unless host

    proxy = host.miq_proxy
    raise "no proxy found on host with guid [#{host_guid}]" unless proxy

    data = MIQEncode.decode(params[:data])
    file = File.join(proxy.logdir, File.basename(params[:filename]))

    $log.info "MIQ(agent-log): [#{params[:options].inspect}]" if params[:options].present?

    File.delete(file) if File.exists?(file)
    $log.info "MIQ(agent-log): Create file: #{file}"
    File.open(file, "wb") { |f| f.write(data) }
    begin
      mtime = params[:mtime].to_i
      File.utime(Time.now, Time.at(mtime), file) unless mtime.zero?
    rescue => err
      $log.error "MIQ(agent-log): Create file: #{err}"
    end

    # If this is the final log to be posted from this request, notify the model to post the zipped logs to the db
    proxy.post_zip_to_db(task_id) if params[:completed].to_s.downcase == 'true' && task_id.present?

    render(:status => "201", :nothing => true)
  end

  private

  def sanitize_guid(an_id)
    an_id.to_s.guid? ? an_id.to_s : nil
  end

  def sanitize_id(an_id)
    an_id.to_s.integer? ? an_id.to_i : nil
  end
end
