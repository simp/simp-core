module Utils
  module_function

  DEFAULT_PASSWORD_LENGTH = 32

  def yes_or_no(prompt, default_yes)
    print prompt + (default_yes ? ' [Y|n]: ' : ' [y|N]: ')
    case STDIN.gets
    when /^(y|Y)/
      true
    when /^(n|N)/
      false
    when /^\s*$/
      default_yes
    else
      yes_or_no(prompt, default_yes)
    end
  end

  def get_password
    print 'Enter password: '

    system('/bin/stty', '-echo')
    password1 = STDIN.gets.strip
    system('/bin/stty', 'echo')
    puts

    print 'Re-enter password: '
    system('/bin/stty', '-echo')
    password2 = STDIN.gets.strip
    system('/bin/stty', 'echo')
    puts

    if password1 == password2
      if validate_password(password1)
        password1
      else
        get_password
      end
    else
      puts "  Passwords do not match! Please try again."
      get_password
    end
  end

  def generate_password(length = DEFAULT_PASSWORD_LENGTH, default_is_autogenerate = true)
    password = ''
    if Utils.yes_or_no('Do you want to autogenerate the password?', default_is_autogenerate )
      special_chars = ['#','%','&','*','+','-','.',':','@']
      symbols = ('0'..'9').to_a + ('A'..'Z').to_a + ('a'..'z').to_a
      Integer(length).times { |i| password += (symbols + special_chars)[rand((symbols.length-1 + special_chars.length-1))] }
      # Ensure that the password does not start or end with a special
      # character.
      special_chars.include?(password[0].chr) and password[0] = symbols[rand(symbols.length-1)]
      special_chars.include?(password[password.length-1].chr) and password[password.length-1] = symbols[rand(symbols.length-1)]
      puts "Your password is:\n#{password}"
      print 'Push [ENTER] to continue.'
      $stdout.flush
      $stdin.gets
    else
      password = Utils.get_password
    end
    password
  end

  def validate_password(password)
    require 'shellwords'

    if password.length < 8
      puts "  Invalid Password: Password must be at least 8 characters long"
      false
    else
      pass_result = `echo #{Shellwords.escape(password)} | cracklib-check`.split(':').last.strip
      if pass_result == "OK"
        true
      else
        puts "  Invalid Password: #{pass_result}"
        false
      end
    end
  end

  def get_value(default_value = '')
    case default_value
    when /\d+\.\d+\.\d+\.\d+/
      print "Enter a new IP: "
      value = STDIN.gets.strip
      while !valid_ip?(value)
        puts "INVALID! Try again..."
        print "Enter a new IP: "
        value = STDIN.gets.strip
      end
    else
      print "Enter a value: "
      value = STDIN.gets.strip
    end
    value
  end

  def generate_certificates(hostname)
    Dir.chdir('/etc/puppet/Config/FakeCA') do
      file = File.open('togen', 'w')
      file.puts hostname
      file.close

      passphrase = `cat cacertkey`.chomp
      system('./gencerts_nopass.sh auto')
    end
  end

  def valid_ip?(value)
    value.to_s =~ /^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/
  end
end
