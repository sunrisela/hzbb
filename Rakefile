#!/usr/bin/env rake
# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path('../app', __FILE__)
# load tasks
Dir[File.join(File.dirname(__FILE__), 'lib', 'tasks', '*.rake')].each{|rake| load rake}