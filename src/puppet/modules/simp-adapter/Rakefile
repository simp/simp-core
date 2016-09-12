#!/usr/bin/rake -T

require 'rake/packagetask'
require 'simp/rake'
require 'simp/rake/beaker'

# Package Tasks
Simp::Rake::Pkg.new(File.dirname(__FILE__))

# Acceptance Tests
Simp::Rake::Beaker.new(File.dirname(__FILE__))
