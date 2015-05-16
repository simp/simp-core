require 'highline/import'
require 'puppet'
require 'yaml'
require File.expand_path( 'utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item
    attr_accessor :key, :value, :description, :fact
    attr_accessor :skip_query, :skip_apply, :skip_yaml, :silent
    attr_accessor :die_on_apply_fail, :allow_user_apply
    attr_accessor :config_items
    attr_accessor :next_items_tree

    def initialize(key = nil, description = nil)
      @key               = key         # answers file key for the config Item
      @description       = description # A text description of the Item
      @value             = nil         # value (decided by user)
      @fact              = nil         # Facter fact to query OS value

      @skip_query        = false       # skip the query and use the default_value
      @skip_apply        = false       # skip the apply
      @skip_yaml         = false       # skip yaml output
      @silent            = false       # no output to stdout/Highline
      @die_on_apply_fail = false       # halt simp config if apply fails
      @allow_user_apply  = false       # allow non-superuser to apply

      @config_items      = {}          # a hash of all previous Config::Items
      # a Hash of additional Items that this Item may need to add to the Queue
      # the keys of the Has are used to look up the queue
      # format:
      #   'answer1' => [ Item1, Item2, .. ]
      #   'answer2' => [ Item3, Item4, .. ]
      @next_items_tree   = {}
    end

    # methods used to infer Item#value
    # --------------------------------------------------------------------------

    # value of item as read from OS (via Facter)
    def os_value
      Facter.value( @fact ) unless @fact.nil?
    end


    # value of Item as read from puppet (via Hiera) #TODO: not used yet
    def puppet_value; nil; end


    # value of Item as recommended by Very Clever Logic (tm)
    def recommended_value; nil; end
    # --------------------------------------------------------------------------


    # String in yaml answer file format, with comments (if any)
    def to_yaml_s
      fail '@key is empty' if "#{@key}".empty?

      x =  "=== #{@key} ===\n"
      x += "#{(description || 'FIXME: NO DESCRIPTION GIVEN')}\n"

      # comment every line that describes the item:
      x =  x.each_line.map{ |y| "# #{y}" }.join

      # add yaml (but stripped of frontmatter and first indent)
      # TODO: should we be using SafeYAML?  http://danieltao.com/safe_yaml/
      x += { @key => @value }.to_yaml.gsub(/^---\s*\n/m, '').gsub(/^  /, '' )
      x += "\n"

      if @skip_yaml
        x.gsub( /^/, '### ' )
      else
        x
      end
    end


    # --------------------------------------------------------------------------
    #  Pretty stdout/stdin methods
    # --------------------------------------------------------------------------
    # print a pretty banner to describe an item
    def print_banner
      return if @silent
      say_blue "=== #{@key} ===", ['BOLD']
      say_blue description
      say_blue "    - os value:          #{os_value}"          if os_value
      say_blue "    - os value:          #{puppet_value}"      if puppet_value
      say_blue "    - recommended value: #{recommended_value}" if recommended_value
      say_blue "    - chosen value:      #{@value}"            if @value
    end


    # print a pretty summary of the Item's key+value, printed to stdout
    def print_summary
      return if @silent
      fail '@key is empty' if "#{@key}".empty?
      say( "#{@key} = '<%= color( %q{#{value}}, BOLD )%>'\n" )
    end


    # choose @value of Item
    def query
      extra = query_status
      if !@skip_query && @value.nil?
        print_banner
        @value = query_ask
      end

      # summarize the item's status after the query is complete
      say( "#{extra}#{@key} = '<%= color( %q{#{@value}}, BOLD )%>'\n" ) unless @silent
    end


    def query_status
      extra = ''
      if !@value.nil?
        extra = "<%= color( %q{(answered)}, CYAN, BOLD)%> "
      elsif @skip_query
        extra = "<%= color( %q{(noninteractive)}, CYAN, BOLD)%> "
        @value = default_value
      end
      extra
    end


    # ask an interactive question (via stdout/stdin)
    def query_ask
      value = ask( "<%= color('#{@key}', WHITE, BOLD) %>:", highline_question_type ) do |q|
        q.default = default_value unless default_value.to_s.empty?

        # validate input via the validate() method
        q.validate = lambda{ |x| validate( x )}

        # if the answer is not valid, construct a reply:
        q.responses[:not_valid] =  "<%= color( %q{Invalid answer!}, RED ) %>\n"
        q.responses[:not_valid] += "<%= color( %q{#{ (not_valid_message || description) }}, CYAN) %>\n"
        q.responses[:not_valid] += "#{q.question}  |#{q.default}|"

        query_extras q
      end
      value
    end


    # returns the default answer to Item#query
    def default_value
      @value || recommended_value
    end


    def query_extras( q ); q; end


    # returns true if x is a valid value
    def validate( _x )
      msg =  'ERROR: Item.validate() not implemented!'
      msg += "\nTODO: cover common type-based validations?"
      msg += "\nTODO: Offer validation objects?"
      fail msg
    end


    def next_items
      @next_items_tree.fetch( @value, [] )
    end


    # optional message to show users when invalid input is entered
    def not_valid_message; nil; end


    # A helper method that highline can use to cast String answers to the ask
    # in query().  nil means don't cast, Date casts into a date, etc.
    # A lambda can be used for sanitization.
    #
    # Descendants of Item are very likely to override this method.
    def highline_question_type; nil; end

    # convenience_method to print formatted information
    def say_blue( msg, options=[] )
      options = options.unshift( '' ) unless options.empty?
      say "<%= color(%q{#{msg}}, CYAN #{options.join(', ')}) %>\n" unless @silent
    end
    def say_yellow( msg, options=[] )
      options = options.unshift( '' ) unless options.empty?
      say "<%= color(%q{#{msg}}, YELLOW #{options.join(', ')}) %>\n" unless @silent
    end
    def say_red( msg, options=[] )
      options = options.unshift( '' ) unless options.empty?
      say "<%= color(%q{#{msg}}, RED #{options.join(', ')}) %>\n" unless @silent
    end
    def say_green( msg, options=[] )
      options = options.unshift( '' ) unless options.empty?
      say "<%= color(%q{#{msg}}, GREEN #{options.join(', ')}) %>\n" unless @silent
    end


    def safe_apply; nil; end
    def apply; nil; end
  end



  # A Item that asks for lists instead of Strings
  #
  #  note that @value is a Strin
  class YesNoItem < Item
    def not_valid_message
      "enter 'yes' or 'no'"
    end

    def validate( v )
      return true if (v.class == TrueClass || v.class == FalseClass)
      ( v =~ /^(y(es)?|true|false|no?)$/i ) ? true : false
    end

    # NOTE: Highline should transform the input to a boolean but doesn't.  Why?
    # REJECTED: Override #query_ask using Highline's #agree? *** no, can't bool
    def highline_question_type
      lambda do |str|
        return true  if ( str =~ /^(y(es)?|true)$/i ? true : false || str.class == TrueClass  )
        return false if ( str =~ /^(n(o)?|false)$/i ? true : false || str.class == FalseClass )
        nil
      end
    end

    # NOTE: when used from query_ask, the highline_question_type lamba doesn't
    # always cast internal type of @value to a boolean.  As a workaround, we
    # cast it here before it is committed to the super's YAML output.
    def to_yaml_s
      _value = @value
      @value = highline_question_type.call @value
      x = super
      @value = _value
      x
    end

    def next_items
      @next_items_tree.fetch( highline_question_type.call( @value ), [] )
    end
  end




  # An Item that asks for Passwords, with:
  #   - special validation
  #   - invisible input
  #   - optional password generation
  class PasswordItem < Item
    attr_accessor :can_generate, :generate_by_default
    def initialize
      super
      @can_generate        = true
      @generate_by_default = true
    end


    def query_extras( q )
      q.echo = '*'     # don't print password characters to stdout
    end


    def encrypt( password, salt=nil )
      say_yellow 'WARNING: password not encrypted; override in child class'
      password
    end


    def query_generate_password
      password = false
      default  = @generate_by_default ? 'yes' : 'no'
      if agree( "generate a password?" ){ |q| q.default = default }
        password = Simp::Cli::Config::Utils.generate_password
        say "<%= color( %q{#{''.ljust(80,'-')}}, GREEN)%>\n"
        say "<%= color( %q{NOTE: }, GREEN, BOLD)%>" +
            "<%= color( %q{ the generated password is: }) %>\n"
        say "\n"
        say "<%= color( %q{   #{password}}, YELLOW, BOLD )%>  "
        say "\n"
        say "\n"
        say "Please remember it!"
        say "<%= color( %q{#{''.ljust(80,'-')}}, GREEN)%>\n"
      end
      password
    end


    # ask for the password twice (and verify that both match)
    def query_ask
      password = false
      password = query_generate_password if @can_generate

      while !password
        answers = []
        [0,1].each{ |x|
          say "please enter a password:"     if x == 0
          say "please confirm the password:" if x == 1
          answers[x] = super
        }
        if answers.first == answers.last
          password = answers.first
        else
          say_yellow( 'WARNING: passwords did not match!  Please try again.' )
        end
      end

      encrypt password
    end


    def validate x
      result = true
      begin
        Simp::Cli::Config::Utils.validate_password x
      rescue Simp::Cli::Config::PasswordError => e
        say_yellow "WARNING: Invalid Password: #{e.message}"
        result = false
      end
      result
    end
  end


  # A Item that asks for lists instead of Strings
  #
  #  note that @value  is now an Array
  class ListItem < Item
    attr_accessor :allow_empty_list

    def initialize
      super
      @allow_empty_list = false
    end

    def not_valid_message
      "enter a comma or space-delimited list"
    end

    def query_extras( q )
      # NOTE: this is a hack to massage Array input to/from a highline query.
      # It would probably be better (but more complex) to provide native Array
      # support for highline.
      # TODO: Override #query_ask using Highline's #gather?
      q.default = q.default.join( " " ) if q.default.is_a? Array
      q
    end

    def highline_question_type
      # Convert the String (delimited by comma and/or whitespace) answer into an array
      lambda { |str|
        str = str.split(/,\s*|,?\s+/) if str.is_a? String
        str
      }
    end

    # validate the list and each item in the list
    def validate( list )
      # reuse the highline lambda to santize input
      return true  if (@allow_empty_list && list.nil?)
      list = highline_question_type.call( list ) if !list.is_a? Array
      return false if !list.is_a?(Array)
      return false if (!@allow_empty_list && list.empty? )
      list.each{ |item|
        return false if !validate_item( item )
      }
      true
    end

    # validate a single list item
    def validate_item( x )
      fail 'not implemented!'
    end
  end


  # mixin that provides common logic for safe_apply()
  module SafeApplying
    def safe_apply
      extra        = ''
      not_root_msg = ''
      if !@allow_user_apply
        not_root_msg = ENV.fetch('USER') == 'root' ? '' : ' [**user is not root**] '
      end

      if @skip_apply || (not_root_msg.size != 0)
        extra = "<%= color( %q{(skipping apply#{not_root_msg})}, MAGENTA, BOLD)%> "
        say( "#{extra}#{@key}" ) unless @silent
        if !(@value.nil? || @value.empty?)
          say( "= '<%= color( %q{#{@value}}, BOLD )%>'\n" ) unless @silent
        end
      else
        extra = "<%= color( %q{(applying changes)}, GREEN, BOLD)%> "
        say( "#{extra}for #{@key}\n" ) unless @silent
        begin
          result = apply
          if result
            extra = "<%= color( %q{(change applied)}, GREEN, BOLD)%> "
          else
            extra = "<%= color( %q{(change failed)}, RED, BOLD)%> "
          end
          say( "#{extra}for #{@key}\n" ) unless @silent
        rescue Exception => e
          extra = "<%= color( %q{(change failed)}, RED, BOLD) %> "
          say( "#{extra}for #{@key}:\n#{e.message}" )
          say "<%= color( %q{#{e.message.to_s.gsub( /^/, '    ' )}}, RED) %> \n"

          # Some failures should be punished by death
          fail e if @die_on_apply_fail
        end
      end
    end
  end


  # A special Item that is never interactive, but applies some configuration
  class ActionItem < Item
    include Simp::Cli::Config::SafeApplying

    def initialize
      super
    end

    # internal method to change the system (returns the result of the apply)
    def apply; nil; end

    # don't be interactive!
    def validate( x ); true; end
    def query;         nil;  end
    def to_yaml_s;     nil;  end
  end
end
