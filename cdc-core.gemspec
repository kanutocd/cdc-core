# frozen_string_literal: true

require_relative 'lib/cdc/core/version'

Gem::Specification.new do |spec|
  spec.name = 'cdc-core'
  spec.version = CDC::Core::VERSION
  spec.authors = ['Ken C. Demanawa']
  spec.email = ['kenneth.c.demanawa@gmail.com']

  spec.summary = 'Source-agnostic Change Data Capture contracts and domain primitives for Ruby.'
  spec.description = <<~DESC
    CDC Core provides immutable, Ractor-safe Change Data Capture contracts and domain primitives,
    including source adapters, change events, processors, routing, ordering policies, and pipelines.
  DESC
  spec.homepage = 'https://github.com/kanutocd/cdc-core'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.4.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['documentation_uri'] = 'https://kanutocd.github.io/cdc-core/'

  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir[
    'lib/**/*.rb',
    'sig/**/*.rbs',
    'README.md',
    'CHANGELOG.md',
    'LICENSE.txt'
  ]
end
