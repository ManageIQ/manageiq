class FilesystemDecorator < Draper::Decorator
  delegate_all

  def fonticon
    convert = {
      "dll"      => "fa fa-cogs",
      "doc"      => "fa fa-file-word-o",
      "exe"      => "fa fa-file-o",
      "ini"      => "fa fa-cog",
      "log"      => "fa fa-file-text-o",
      "pdf"      => "fa fa-file-pdf-o",
      "txt"      => "fa fa-file-text-o",
      "unknown"  => "fa fa-file-o",
      "zip"      => "fa fa-file-archive-o"
    }
    convert[name.downcase] || "fa fa-file-o"
  end

end
