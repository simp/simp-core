module Simp; end
class Simp::Cli; end
module Simp::Cli::Config; end

require File.expand_path( '../commands/config', File.dirname(__FILE__) )
require File.expand_path( 'utils', File.dirname(__FILE__) )
require 'yaml/store' # for safety-saving

# Builds a SIMP configuration profile based on an Array of Config::Items
#
# The configuration profile is built on a Questionnaire, which is interactive
# by default, but can be automated.
#
class Simp::Cli::Config::Questionnaire

  INTERACTIVE           = 0
  NONINTERACTIVE        = 1
  REALLY_NONINTERACTIVE = 2

  def initialize( options = {} )
    @options = {
     :noninteractive => INTERACTIVE,
     :verbose        => 0
    }.merge( options )
  end


  # processes an Array of Config::Items and returns a hash of Config::Item
  # answers
  def process( item_queue=[], answers={} )
    if item = item_queue.shift
      item.config_items = answers
      process_item item

      # add (or replace) this item's answer to the answers list
      answers[ item.key ] = item

      # add any next_items to the queue
      item_queue = item.next_items + item_queue

      process item_queue, answers
    end

    answers
  end


  # process a Config::Item
  #
  # simp config can run in the following modes:
  #   - interactive (prompt each item)
  #   - mostly non-interactive (-f; prompt items that can't be inferred)
  #   - never prompt (-ff; relies on cli args for non-inferrable items))
  def process_item item
    item.skip_query = true if @options[ :noninteractive ] >= NONINTERACTIVE
    if @options[ :noninteractive ] == INTERACTIVE
      item.query
    else
      value = item.default_value

      if item.validate( value )
        item.value = value
        item.print_summary if @options.fetch( :verbose ) >= 0
      else
        # alert user that the value is wrong
        print_invalid_item_error item

        # present an interactive prompt for invalid answers unless '-ff'
        exit 1 if @options.fetch( :noninteractive ) >= REALLY_NONINTERACTIVE
        item.skip_query = false
        value = item.query
      end
    end
    item.safe_apply
  end

  def print_invalid_item_error item
    error =  "ERROR: '#{item.value}' is not a valid value for #{item.key}"
    error += "\n#{item.not_valid_message}" if item.not_valid_message
    say "<%= color(%q{#{error}}, RED) %>\n"
  end
end
