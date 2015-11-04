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
    success_count = 0
    failed_count = 0

    files.each do |file|
      # FileUtils.rm(file) if send_file(@ping_bucket, File.basename(file), file)
      uploaded_file = send_file(@ping_bucket, File.basename(file), file)

      if uploaded_file
        if verify_upload(uploaded_file)
          success_count += 1
          FileUtils.rm(file) 
        else
          file.delete # data was corrupt, delete from S3
          failed_count += 1
        end
      end
    end

    if files.count > 0
      puts "#{success_count} file(s) uploaded successfully. #{failed_count} failed."
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

  def verify_upload(file)
    # this seems kind of redundant but we're going to do it anyway.
    # download the file we just uploaded, unzip and run its data through the hasher
    # and compare it to its filename to ensure data integrity.

    tmp = File.open("#{$pingbox_root}/tmp/tmp.gz", "wb+") do |temp_file|
      temp_file.write(file.get[:body].read)
    end

    system "gzip -fd '#{$pingbox_root}/tmp/tmp.gz'"
    data = File.open("#{$pingbox_root}/tmp/tmp", 'r').read

    original_hash = file.key.split('.').first
    new_hash = Digest::SHA2.new(512).update(data).hexdigest

    FileUtils.rm("#{$pingbox_root}/tmp/tmp")
    return original_hash == new_hash ?  true : false
  end

end

