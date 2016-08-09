require_relative "../MiqDisk"
require 'ostruct'

module AzureBlobDisk
  # The maximum read length that supports MD5 return.
  MAX_READ_LEN = 1024 * 1024 * 4

  def self.new(svc, blob_uri, dInfo = nil)
    d_info = dInfo || OpenStruct.new
    d_info.storage_acct_svc = svc
    d_info.blob_uri         = blob_uri
    d_info.fileName         = blob_uri

    MiqDisk.new(self, d_info, 0)
  end

  def d_init
    @diskType         = "azure-blob"
    @blockSize        = 512
    @blob_uri         = @dInfo.blob_uri
    @storage_acct_svc = @dInfo.storage_acct_svc

    uri_info   = @storage_acct_svc.parse_uri(@blob_uri)
    @container = uri_info[:container]
    @blob      = uri_info[:blob]
    @acct_name = uri_info[:account_name]
    @snapshot  = uri_info[:snapshot]

    @storage_acct = @storage_acct_svc.accounts_by_name[@acct_name]
    raise "AzureBlob: Storage account #{@acct_name} not found." unless @storage_acct

    $log.debug "AzureBlobDisk: open(#{@blob_uri})"
    @t0 = Time.now.to_i
    @reads = 0
    @bytes = 0
    @split_reads = 0
  end

  def d_close
    return nil unless $log.debug?
    t1 = Time.now.to_i
    $log.debug "AzureBlobDisk: close(#{@blob_uri})"
    $log.debug "AzureBlobDisk: (#{@blob_uri}) time:  #{t1 - @t0}"
    $log.debug "AzureBlobDisk: (#{@blob_uri}) reads: #{@reads}, split_reads: #{@split_reads}"
    $log.debug "AzureBlobDisk: (#{@blob_uri}) bytes: #{@bytes}"
    nil
  end

  def d_read(pos, len)
    $log.debug "AzureBlobDisk#d_read(#{pos}, #{len})"
    return blob_read(pos, len) unless len > MAX_READ_LEN

    @split_reads += 1
    ret = ""
    blocks, rem = len.divmod(MAX_READ_LEN)

    blocks.times do
      ret << blob_read(pos, MAX_READ_LEN)
    end
    ret << blob_read(pos, rem) if rem > 0

    ret
  end

  def d_size
    @d_size ||= blob_properties[:content_length].to_i
  end

  def d_write(_pos, _buf, _len)
    raise "Write operation not supported."
  end

  private

  def blob_read(start_byte, length)
    $log.debug "AzureBlobDisk#blob_read(#{start_byte}, #{length})"
    options = {
      :start_byte => start_byte,
      :length     => length
    }
    options[:date] = @snapshot if @snapshot

    ret = @storage_acct.get_blob_raw(@container, @blob, key, options)

    @reads += 1
    @bytes += ret.body.length

    ret.body
  end

  def blob_properties
    @blob_properties ||= begin
      options = @snapshot ? {:date => @snapshot} : {}
      @storage_acct.blob_properties(@container, @blob, key, options)
    end
  end

  def key
    @key ||= @storage_acct_svc.list_account_keys(@storage_acct.name, @storage_acct.resource_group).fetch('key1')
  end
end
