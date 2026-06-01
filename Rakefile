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

desc 'Generate RBS signatures'
task :rbs do
  sh 'rm -rf sig'
  sh 'bundle exec rbs prototype rb --out-dir=sig --base-dir=lib lib'
end

desc 'Validate RBS signatures'
task :rbs_validate do
  sh 'bundle exec steep check'
end
