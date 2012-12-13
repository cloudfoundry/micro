$:.unshift(File.expand_path("../../lib", __FILE__))

ENV['BUNDLE_GEMFILE'] ||= File.expand_path("../../Gemfile", __FILE__)
require 'rubygems'
require 'bundler'
Bundler.setup(:default, :test)
require 'rspec'
require 'rack/test'

$:.unshift(File.expand_path("../../../agent/lib", __FILE__))

ENV['LOGFILE'] = "tmp/micro.log"

module VCAP
  module Micro
    class BoshWrapper
    end
    class Console
    end
    class Compiler
    end
  end
end

require 'micro/api'

class VCAP::Micro::Api::Server
  use VCAP::Micro::Api::Engine::Rack::MediaTypeSerial
end

require 'micro/version'

def with_warnings(flag)
  old_verbose, $VERBOSE = $VERBOSE, flag
  yield
ensure
  $VERBOSE = old_verbose
end

def constantize(string)
  string.split('::').inject(Object) {|memo,name| memo =  memo.const_get(name); memo}
end

def parse(constant)
  source, _, constant_name = constant.to_s.rpartition('::')

  [constantize(source), constant_name]
end

def with_constants(constants, &block)
  saved_constants = {}
  constants.each do |constant, val|
    source_object, const_name = parse(constant)

    saved_constants[constant] = source_object.const_get(const_name)
    # Kernel::silence_warnings { source_object.const_set(const_name, val) }
    with_warnings(nil) { source_object.const_set(const_name, val) }
  end

  begin
    block.call
  ensure
    constants.each do |constant, val|
      source_object, const_name = parse(constant)

      # Kernel::silence_warnings { source_object.const_set(const_name, saved_constants[constant]) }
      with_warnings(nil) { source_object.const_set(const_name, saved_constants[constant]) }
    end
  end
end

class String
  def strip_heredoc
    string = scan(/^[ \t]*(?=\S)/).min
    indent = string ? string.size : 0
    gsub(/^[ \t]{#{indent}}/, '')
  end
end

# e.g. path_to_foo.should be_same_file_as(path_to_bar)
RSpec::Matchers.define(:be_same_file_as) do |exected_file_path|
  match do |actual_file_path|
    md5_hash(actual_file_path).should == md5_hash(exected_file_path)
  end

  def md5_hash(file_path)
    Digest::MD5.hexdigest(File.read(file_path))
  end
end
