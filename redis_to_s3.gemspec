# Ensure we require the local version and not one we might have installed already
require File.join([File.dirname(__FILE__),'lib','redis_to_s3','version.rb'])
spec = Gem::Specification.new do |s| 
  s.name = 'redis_to_s3'
  s.version = Redis_to_S3::VERSION
  s.author = 'Kostiantyn Lysenko'
  s.email = 'gshaud@gmail.com'
  s.homepage = 'http://jakshi.com'
  s.platform = Gem::Platform::RUBY
  s.summary = 'Redis to S3 dumper'
  s.description = 'Dump keys from Redis based an pattern from util config file and upload dump to S3'
  s.licenses = ["Apache License, Version 2.0"]
  s.files = `git ls-files`.split("
")
  s.require_paths << 'lib'
  s.bindir = 'bin'
  s.executables << 'redis_to_s3'
  s.add_development_dependency('rake')
  s.add_runtime_dependency('settingslogic')
  s.add_runtime_dependency('redis')
  s.add_runtime_dependency('aws-sdk')
  s.add_runtime_dependency('optimist')
end
