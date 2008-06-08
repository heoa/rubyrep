require 'rake'
require 'benchmark'

require File.dirname(__FILE__) + '/../sim_helper'

class LeftBigScan < ActiveRecord::Base
  set_table_name "big_scan"
  include CreateWithKey
end

class RightBigScan < ActiveRecord::Base
  set_table_name "big_scan"
  include CreateWithKey
end

# Prepares the database schema for the big_scan test.
# db_connection holds the database connection to be used.
def big_scan_prepare_schema(db_connection)
  ActiveRecord::Base.connection = db_connection

  ActiveRecord::Schema.define do
    drop_table :big_scan rescue nil
    create_table :big_scan do |t|
      t.column :diff_type, :string
      t.string :text1, :text2, :text3, :text4
      t.text :text5
      t.binary :text6
      t.integer :number1, :number2, :number3
      t.float :number4
    end rescue nil
  end  
end

BIG_SCAN_RECORD_NUMBER = 5000 # number of records to create for simulation
BIG_SCAN_SEED = 123 # random number seed to make simulation repeatable

# Percentage values for same, modified, left_only and right_only records in simulation
BIG_SCAN_SAME = 95
BIG_SCAN_MODIFIED = BIG_SCAN_SAME + 3
BIG_SCAN_LEFT_ONLY = BIG_SCAN_MODIFIED + 1 # difference to 100% will be right_only records 

def text_columns
  @@text_columns ||= LeftBigScan.column_names.select {|column_name| column_name =~ /^text/}
end

def number_columns
  @@number_columns ||= LeftBigScan.column_names.select {|column_name| column_name =~ /^number/}
end

def random_attributes
  attributes = {}
  text_columns.each {|column_name| attributes[column_name] = "text#{rand(1000)}"}
  number_columns.each {|column_name| attributes[column_name] = rand(1000)}
  attributes
end

# Populates the big_scan tables with sample data.
# Takes a Session object holding the according database connection.
def big_scan_populate_data(session)
  LeftBigScan.connection = session.left.connection
  RightBigScan.connection = session.right.connection
  
  LeftBigScan.delete_all
  RightBigScan.delete_all
  
  srand BIG_SCAN_SEED

  puts "Populating #{BIG_SCAN_RECORD_NUMBER} records"
  progress_bar = ProgressBar.new BIG_SCAN_RECORD_NUMBER
  
  (1..BIG_SCAN_RECORD_NUMBER).each do |i|
    
    # Updating progress bar
    progress_bar.step
    
    attributes = random_attributes
    attributes['id'] = i
    
    case rand(100)
    when 0...BIG_SCAN_SAME
      attributes['diff_type'] = 'same'
      LeftBigScan.create_with_key attributes
      RightBigScan.create_with_key attributes
    when BIG_SCAN_SAME...BIG_SCAN_MODIFIED
      attributes['diff_type'] = 'conflict'
      LeftBigScan.create_with_key attributes
      
      attribute_name = text_columns[rand(text_columns.size)]
      attributes[attribute_name] = attributes[attribute_name] + 'modified'
      attribute_name = number_columns[rand(number_columns.size)]
      attributes[attribute_name] = attributes[attribute_name] + 10000
      RightBigScan.create_with_key attributes
    when BIG_SCAN_MODIFIED...BIG_SCAN_LEFT_ONLY
      attributes['diff_type'] = 'left'
      LeftBigScan.create_with_key attributes
    else
      attributes['diff_type'] = 'right'
      RightBigScan.create_with_key attributes
    end
  end
end

# Prepares the database for the big_scan test
def big_scan_prepare
  session = RR::Session.new
  [:left, :right].each {|arm| big_scan_prepare_schema(session.send(arm).connection)}
  puts "time required: " + Benchmark.measure {big_scan_populate_data session}.to_s
end

namespace :sims do
  namespace :big_scan do
    desc "Prepare database"
    task :prepare do
      big_scan_prepare
    end
    
    desc "Runs the big_scan simulation"
    task :run do
      Spec::Runner::CommandLine.run(
        Spec::Runner::OptionParser.parse(
          ['--options', "spec/spec.opts", "./sims/big_scan/big_scan_spec.rb"], 
          $stdout, $stderr))
    end
    
    begin
      require 'ruby-prof/task'
      RubyProf::ProfileTask.new do |t|
        t.test_files = FileList["./sims/big_scan/big_scan_spec.rb"]
        t.output_dir = 'profile'
        t.printer = :flat
        t.min_percent = 1
      end
    rescue LoadError
    end
  end
end