require 'aws-sdk'
require 'settingslogic'
require 'trollop'
require 'redis'
require 'time'

module Redis_to_S3
  
  class CLI
    class Settings < Settingslogic
    end
    
    def initialize(argv)
      @opts = Trollop::options do
        opt :config, "config file path", :type => :string, :default => '/etc/redis_to_s3/config.yml'
      end

      unless ::File.exists?(::File.expand_path(@opts[:config]))
        puts "Config file #{@opts[:config]} doesn't exist!"
        exit 1
      end

      @settings = Settings.new(@opts[:config])
      Aws.config.update({
                          region: 'us-east-1',
                          credentials: Aws::Credentials.new(@settings.aws.aws_access_key_id, @settings.aws.aws_secret_access_key)
                        })
      @s3 = Aws::S3::Client.new(region: 'us-east-1')

      @data = []
      @file_to_upload = ""
    end

    def timestamp
      Time.now.getutc.to_i
    end

    def run
      setup
      copy
      compress
      upload
      clean
    end

    def setup
      begin
        puts "creating AWS S3 bucket '#{@settings.aws.s3_bucket}' for storing Redis Chronicle data"
        @s3.create_bucket({bucket: @settings.aws.s3_bucket})
      rescue Aws::S3::Errors::BucketAlreadyOwnedByYou
        puts "AWS S3 bucket '#{@settings.aws.s3_bucket}' exists already, nothing to do"
      end
    end

    def copy
      puts "Dump Chronicle Redis keys specified in #{@opts[:config]} config to #{@settings.dirs.temp}/binary_chronicle_redis.dump"
      # Get keys
      redis = Redis.new(:port => 6381)
      keys = []
      @settings.redis.each do |pattern|
        keys += redis.scan_each(:match => "#{pattern}*").to_a
      end
      # Get data
      keys.each do |key|
        @data << key + ' ' + redis.get(key)
      end
      # Put data in temporary file
      File.open("#{@settings.dirs.temp}/binary_chronicle_redis.dump", "w+") do |f|
        @data.each { |el| f.puts(el) }
      end
    end

    def compress
      FileUtils.rm Dir.glob("#{@settings.dirs.temp}/binary_chronicle_redis.dump.*.tar.pigz"), :force => true

      @file_to_upload = "binary_chronicle_redis.dump.#{timestamp}.gz"
      puts "Compress current Chronicle Redis dump to #{@settings.dirs.temp}/#{@file_to_upload}"
      `gzip < #{@settings.dirs.temp}/binary_chronicle_redis.dump > #{@settings.dirs.temp}/#{@file_to_upload}`
    end

    def upload
      puts "Upload #{@settings.dirs.temp}/#{@file_to_upload} Chronicle Redis dump to AWS S3 #{@settings.aws.s3_bucket} bucket"
      File.open("#{@settings.dirs.temp}/#{@file_to_upload}", 'rb') do |f|
        @s3.put_object(bucket: @settings.aws.s3_bucket, key: @file_to_upload, body: f)
      end
      @s3.wait_until(:object_exists, bucket: @settings.aws.s3_bucket, key: @file_to_upload)
    end

    def clean
      puts "Clean old images for Chronicle Redis from AWS S3"
      max_files = @settings.aws.max_files
      a = []
      @s3.list_objects(bucket: @settings.aws.s3_bucket).contents.each { |c| a << c.key }
      if a.length > max_files
        a.sort!.reverse!
        a.drop(max_files).each do |key|
          @s3.delete_object(bucket: @settings.aws.s3_bucket, key: key)
          @s3.wait_until(:object_not_exists, bucket: @settings.aws.s3_bucket, key: key)
        end
      end
    end
  end
end
