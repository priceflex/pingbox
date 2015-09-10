$pingbox_root = "#{File.dirname(__FILE__)}/.." unless $pingbox_root
$config_dir = "#{$pingbox_root}/config"

require 'yaml'
require 'fileutils'

# make sure that all environment files are in their proper location.

["env", "machine", "public_ip", "test_case"].each do |config_file|

  if File.exists?("#{$config_dir}/#{config_file}.yml")
    # yay we're good, sit back and drink lemonade
  else
    # look in the root dir for the files
    if File.exists?("#{$pingbox_root}/#{config_file}.yml")
      # move it to the config dir
      FileUtils.mv("#{$pingbox_root}/#{config_file}.yml", "#{$config_dir}/#{config_file}.yml")
      puts "#{config_file}.yml was out of place.  moved it to the config directory."
    end
  end

end
