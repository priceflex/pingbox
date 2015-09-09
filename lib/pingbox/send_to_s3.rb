$pingbox_root = "#{File.dirname(__FILE__)}/../.." unless $pingbox_root

require 'pry'
require 'aws-sdk'
require "#{$pingbox_root}/lib/ping/ping"

class SendToS3

  attr_accessor :s3, :ping_bucket, :speed_bucket

  def initialize
    @s3 = Aws::S3::Client.new(
      :access_key_id     => ENV['ec2_access_key_id'],
      :secret_access_key => ENV['ec2_secret_access_key'],
      :region            => ENV['AWS_REGION']
    )

    if Ping.env? == :production
      @ping_bucket = "pingbox-data"
      @speed_bucket = "pingbox-speedtest-us"
    else
      @ping_bucket = "pingbox-data-dev"
      @speed_bucket = "pingbox-speedtest-us-dev"
    end
  end

  def upload_ping_files
    puts "Uploading contents of pingbox/data/ to S3..."
    files = Dir.glob("#{$pingbox_root}/data/*.gz")

    files.each do |file|
      FileUtils.rm(file) if send_file(@ping_bucket, File.basename(file), file)
    end

    if files.count > 0
      puts "#{files.count} file(s) uploaded successfully."
    else
      puts "No files to upload."
    end
  end

  def upload_speed_test
    file_name = "#{(rand * 100000).to_i}"
    send_file(@speed_bucket, file_name, "#{$pingbox_root}/upload.file")
  end

  def send_file(bucket, file_name, file)
    bucket_obj = Aws::S3::Object.new(bucket, "#{file_name}", client: @s3)
    bucket_obj.upload_file(file)
    return bucket_obj
  end
end

