# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'minitest/test_task'
require 'rubocop/rake_task'
require 'yard'

desc 'Run tests'
task :test do
  test_files = Dir['test/**/*_test.rb'].map { |file| "require_relative #{file.inspect}" }.join('; ')

  sh [
    RbConfig.ruby,
    '-r./test/coverage_helper',
    '-Ilib:test',
    '-w',
    '-e',
    test_files.inspect
  ].join(' ')
end

RuboCop::RakeTask.new(:rubocop) do |task|
  task.options = ['--parallel']
end

YARD::Rake::YardocTask.new(:yard) do |task|
  task.files = ['lib/**/*.rb']
  task.options = ['--protected']
end

task default: %i[test rubocop yard]
