load 'boot.rb'
require 'rubygems'
require 'bundler/setup'
require 'rake/testtask'
require 'minitest'
require 'minitest/autorun'
require './test/test_helper'
require './lib/performance_test'

Rake::TestTask.new(:test) do |t|
  t.libs = %w(lib test)
  t.pattern = 'test/**/*_test.rb'
end

task default: :test
