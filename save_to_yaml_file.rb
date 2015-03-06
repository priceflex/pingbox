require 'yaml'
require "#{File.dirname(__FILE__)}/hasher.rb"

@@current_path = "#{File.dirname(__FILE__)}"

class SaveToYmlFile
  def initialize(filename, data)
    @filename = filename
    @data = data

    save_staging_file
    sha_file
    zip_file

  end

  def save_staging_file
    File.open("#{@@current_path}/#{@filename}", "w+") {|f| f.write(@data.to_yaml) }
  end

  def sha_file
    @hash_file_name ||= Hasher.new("#{@@current_path}/#{@filename}").hashsum
  end

  def zip_file
    system("gzip -9 #{@@current_path}/#{@filename}")
    FileUtils.mv "#{@@current_path}/#{@filename}.gz", "#{@@current_path}/data/#{@hash_file_name}.gz"
  end
end
