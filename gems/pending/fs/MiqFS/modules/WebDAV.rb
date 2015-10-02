#
# Copyright 2015 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'uri'
require 'net/http'

require 'fs/MiqFS/modules/WebDAVFile'

module WebDAV
  attr_reader :guestOS

  def fs_init
    @fsType = "WebDAV"
    @guestOS = @dobj.guest_os

    @uri = URI(@dobj.uri.to_s)
    @headers = @dobj.headers || {}

    @connection = Net::HTTP.start(
      @uri.host,
      @uri.port,
      :use_ssl     => @uri.scheme == 'https',
      :verify_mode => @dobj.verify_mode || OpenSSL::SSL::VERIFY_PEER
    )
  end

  def fs_unmount
    @connection.finish
  end

  def freeBytes
    0
  end

  def fs_dirEntries(_path)
    raise NotImplementedError
  end

  def fs_fileExists?(path)
    response = WebDAVFile.head_response(@connection, remote_uri(path), @headers)
    case response
    when Net::HTTPOK
      return true
    when Net::HTTPNotFound
      return false
    else
      raise Errno::EINVAL
    end
  end

  def fs_fileDirectory?(path)
    # TODO: implement proper check for being a directory
    path += '/' unless path.end_with?('/')
    fs_fileExists?(path)
  end

  def fs_fileFile?(_path)
    raise NotImplementedError
  end

  def fs_fileSize(path)
    WebDAVFile.file_size(remote_uri(path))
  end

  def fs_fileSize_obj(fobj)
    fobj.size
  end

  def fs_fileAtime(_path)
    raise NotImplementedError
  end

  def fs_fileCtime(_path)
    raise NotImplementedError
  end

  def fs_fileMtime(_path)
    raise NotImplementedError
  end

  def fs_fileAtime_obj(_fobj)
    raise NotImplementedError
  end

  def fs_fileCtime_obj(_fobj)
    raise NotImplementedError
  end

  def fs_fileMtime_obj(_fobj)
    raise NotImplementedError
  end

  def fs_fileOpen(path, mode = "r")
    raise Errno::EACCES unless mode == 'r'
    WebDAVFile.new(remote_uri(path), @connection.verify_mode, @headers)
  end

  def fs_fileSeek(fobj, offset, whence)
    fobj.seek(offset, whence)
  end

  def fs_fileRead(fobj, len)
    fobj.read(len)
  end

  def fs_fileClose(fobj)
    fobj.close
  end

  def fs_fileWrite(_fobj, _buf, _len)
    raise Errno::EACCES
  end

  def fs_dirMkdir(_path)
    raise Errno::EACCES
  end

  def dirRmdir(_path)
    raise Errno::EACCES
  end

  def fs_fileDelete(_path)
    raise Errno::EACCES
  end

  private

  def remote_uri(path)
    @uri.merge(@uri.path + path)
  end
end
