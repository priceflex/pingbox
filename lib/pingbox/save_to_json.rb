$pingbox_root = "#{File.dirname(__FILE__)}/../.." unless $pingbox_root

require 'json'

require "#{$pingbox_root}/lib/pingbox/hasher"

class SaveToJson

  def initialize(filename, data)
    @filename = filename
    @data     = data
    save_staging_file
    sha_file
  end

  def save_staging_file
    File.open("#{$pingbox_root}/#{@filename}", "w+") { |f| f.write(@data.to_json) }
  end

  def sha_file
    @hash_file_name ||= Hasher.new("#{$pingbox_root}/#{@filename}").hashsum
  end

end

