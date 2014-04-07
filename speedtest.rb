# This will make a 5MB File

#fallocate -l 5M upload.file

@@current_path = "#{File.dirname(__FILE__)}"

require 's3'
require 'yaml'
require 'net/http'
require 'uri'

class SpeedTest

  def initialize
    @s3 = S3::Service.new(
      :access_key_id     => ENV['ec2_access_key_id'], 
      :secret_access_key => ENV['ec2_secret_access_key']
    )
    begin
      @bucket = @s3.buckets.find('pingbox-speedtest-us')

      @upload_speed = 0.0
      @donlowad_speed = 0.0
      start_speed_test
      send_results
    rescue
      puts "Cannot connect to s3"
    end
  end

  def start_speed_test
    start_time = Time.now
    file_size = File.size("#{@@current_path}/upload.file") / 1024.0 / 1024.0
    file_name = "#{(rand * 100000).to_i}"
    new_object = @bucket.objects.build("#{file_name}")
    new_object.content = File.open("#{@@current_path}/upload.file")
    new_object.save
    end_time = Time.now

    new_object.destroy

    @upload_speed = (file_size / (end_time - start_time)) * 8



    start_time = Time.now
    system("wget https://pingbox-speedtest-us.s3.amazonaws.com/5mb-download.file -O #{@@current_path}/5mb-download.file")
    end_time = Time.now
    system("rm #{@@current_path}/5mb-download.file")


    @download_speed = (file_size / (end_time - start_time)) * 8

  end

  def send_results
    if File.exist?("#{@@current_path}/machine.yml") && File.exist?("#{@@current_path}/test_case.yml")
      test = YAML.load(File.open("#{@@current_path}/test_case.yml"))
      machine = YAML.load(File.open("#{@@current_path}/machine.yml"))


      data = {
        :speed_data  => {
        :upload_speed => @upload_speed,
        :download_speed => @download_speed,
        :test_case_id => test[:test_case_id],
        :machine_id => machine[:machine_id],
        :time => Time.now.to_i * 1000
      }
      }
      begin
        postData = Net::HTTP.post_form(URI.parse("http://ping.techrockstars.com/machine/#{machine[:machine_id]}/speed_test"),data)
      rescue
        puts "Cannot send results"
      end

    end

  end


end

SpeedTest.new

