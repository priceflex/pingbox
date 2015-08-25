$pingbox_root = "#{File.dirname(__FILE__)}/../.." unless $pingbox_root

require 'yaml'
require "#{$pingbox_root}/lib/pingbox/hasher"

class SaveToYmlFile

  def initialize(filename, data)
    @filename = filename
    @data = data

    save_staging_file
    sha_file
    zip_file
  end

  def save_staging_file
    File.open("#{$pingbox_root}/#{@filename}", "w+") {|f| f.write(@data.to_yaml) }
  end

  def sha_file
    @hash_file_name ||= Hasher.new("#{$pingbox_root}/#{@filename}").hashsum
  end

  def zip_file
    system("gzip -9 #{$pingbox_root}/#{@filename}")
    FileUtils.mv "#{$pingbox_root}/#{@filename}.gz", "#{$pingbox_root}/data/#{@hash_file_name}.gz"
  end
end
