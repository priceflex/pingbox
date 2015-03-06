require 'aws-sdk'
require './ping.rb'

@@current_path = "#{File.dirname(__FILE__)}"

class SendToS3


  class << self

    def connect_s3
      @s3_service ||= Aws::S3::Client.new(
        :access_key_id     => ENV['ec2_access_key_id'],
        :secret_access_key => ENV['ec2_secret_access_key'],
        :region            => ENV['AWS_REGION']
      )
    end

    def send_files

      connect_s3

      begin
        Ping.env? == :production ? bucket_name = "pingbox-data" : bucket_name = "pingbox-data-dev"
        #bucket = Aws::S3::Bucket.new(bucket_name, @s3_service)


        # Copy to S3
        puts "Uploading file to s3"
        Dir.glob("#{@@current_path}/data/*.gz") do |file|
          FileUtils.rm(file) if send_file(bucket_name, File.basename(file), file)
        end
        puts "Sent all data to s3"
      rescue Exception => e
        puts "Error Sending to S3\n#{e.to_s}\n#{e.backtrace}"
      end

    end

    def upload_speed_test
      connect_s3
      #bucket = Aws::S3::Bucket.new("pingbox-speedtest-us", @s3_service)
      bucket_name = "pingbox-speedtest-us"
      file_name = "#{(rand * 100000).to_i}"
      send_file(bucket_name, file_name, "#{@@current_path}/upload.file")
    end

    def send_file(bucket, file_name, file)
      bucket_obj = Aws::S3::Object.new(bucket, "#{file_name}", client: @s3_service)
      bucket_obj.upload_file(file)
      return bucket_obj
    end
  end
end

