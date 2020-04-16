#!env ruby
=begin
Started By: Richard A Secor <rsecor@rsecor.com>
Started On: (around) 2018-07-01
Current Version: 0.3.27.rb
Todo:
  * Error checking... etc

Description: This script is to enable a basic connection to various text-based games from Simutronics.
=end

# config.active_record.default_timezone = :utc
ENV['TZ'] = 'UTC'

Process.setproctitle("play.rb")
version = '0.3.27'

require 'fileutils'

dir = Hash.new
dir[ 'base' ] = __dir__
dir[ 'scripts' ] = dir[ 'base' ] + "/scripts"

def argv_parse(option)
  single = []
  if option.include? "="
    single = option.split('=')
  else
    single.push(option)
  end
  if single.size == 1
    single.push(true)
  end
  @input[single[0]] = single[1]
end

@input = {}
ARGV.each { |option| argv_parse(option) }
p @input

time_out = 90 

background = false
if @input['--background']
  background = true
end

username = nil
if @input['--username']
  username = @input [ '--username' ]
end

password = nil
if @input['--password']
  password = @input [ '--password' ]
end

game_code = ""
if @input['--game_code']
  game_code = @input [ '--game_code' ]
end

character_code = ""
if @input['--character_code']
  character_code = @input [ '--character_code' ]
end

type = 'XML'
if @input['--type']
  type = @input [ '--type' ]
end

# Clear screen -- where available on platform
puts "\e[H\e[2J"

hashpass = '' ;

require 'socket'

fp = TCPSocket.new 'eaccess.play.net', 7900
fp.send "K\n", 0
hashkey = fp.gets

pos = 0
password.split('').each { |c|
  ordhk = hashkey [ pos ].ord
  ordpw = c.ord
  hashpass += ( ( ( ordpw - 32 ) ^ ordhk ) + 32 ).chr
  pos += 1
}
password = nil

fp.send "A\t#{username}\t#{hashpass}\n",0

loginkey = fp.gets.split("\t")
if loginkey[2].strip == 'PASSWORD'
  puts "ERROR: Bad Password\n"
  fp.close
  exit
end

@game_list = {}
@game_codes = {}
if loginkey.empty?
  puts "FATAL ERROR: How did we get here?\n"
  fp.close
  exit
else
  loginkey = nil
  hashpass = nil
  fp.send "M\n",0
  line_no = 0
  game_no = 0
  games = fp.gets.split("\t")
  games.each { |game|
    line_no += 1
    if line_no > 1
      if line_no.remainder(2) == 0
        game_no += 1
        @game_list[games[line_no - 1]] = games[line_no].strip
        @game_codes[game_no] = games[line_no - 1]
      end
    end
  }
end
if @game_list.size == 0
  puts "No games found.\n"
  fp.close
  exit
end
until not game_code.empty? do
  # Clear screen -- where available on platform
  puts "\e[H\e[2J"
  game_no = 0
  @game_list.each { |(local_game_code,local_game_name)|
    game_no += 1
    puts "#{game_no}: #{local_game_code}: #{local_game_name}"
  }
  puts "Enter Game #: "
  local_input = $stdin.gets.chomp
  if local_input.to_i > 0 and local_input.to_i <= game_no
    game_code = @game_codes[local_input.to_i]
    game_name = @game_list[game_code]
  end
end

fp.send "G\t#{game_code}\n", 0
stub = fp.gets.split("\t")
fp.send "P\t#{game_code}\n", 0
stub = fp.gets.split("\t")

@character_list = {}
@character_codes = {}
line_no = 0
character_no = 0
fp.send "C\n", 0
characters = fp.gets.split("\t")
characters.each { |character|
  line_no += 1
  if line_no > 4
    if line_no.remainder(2) == 0
      character_no += 1
      @character_list[characters[line_no - 1]] = characters[line_no].strip
      @character_codes[character_no] = characters[line_no - 1]
    end
  end
}
if @character_list.size == 0
  puts "No characters found.\n"
  fp.close
  exit
end
until not character_code.empty? do
  # Clear screen -- where available on platform
  puts "\e[H\e[2J"
  character_no = 0
  @character_list.each { |(local_character_code,local_character_name)|
    character_no += 1
    puts "#{character_no}: #{local_character_code}: #{local_character_name}"
  }
  puts "Enter Character #: "
  local_input = $stdin.gets.chomp
  if local_input.to_i > 0 and local_input.to_i <= character_no
    character_code = @character_codes[local_input.to_i]
    character_name = @character_list[character_code]
  end
end

puts "\e[H\e[2J"
puts "Entering #{game_name} as #{character_name}\n"

dir[ 'character' ] = dir[ 'base' ] + "/" + game_code + "/" + character_name
if not File.exists?(dir [ 'character' ])
        puts "Missing #{dir [ 'character' ]}\n"
        if FileUtils.mkdir_p dir [ 'character' ]
                puts "Created #{dir [ 'character' ]}\n" ;
        else
                puts "Cannot Create #{dir [ 'character' ]}\n" ;
  		fp.close
                exit
        end
end
if not File.directory?(dir [ 'character' ])
        puts "#{dir [ 'character' ]} IS NOT A FOLDER!\n"
  	fp.close
        exit
end

fp.send "L\t#{character_code}\tSTORM\n", 0
launch = fp.gets.strip.split("\t")

if launch[0] == 'L'
  if launch[1] == 'PROBLEM'
    puts "Subscription Failure...\n"
    fp.close
    exit
  end
else
  puts "Login Failure...\n"
  fp.close
  exit
end

@game = {}
@game[ 'host' ] = ''
@game[ 'port' ] = ''
sal_file = ""
line_no = 0
launch.each { |line|
  line = line.strip
  line_no += 1
  case line
    when /^FULLGAMENAME=/
      line = "FULLGAMENAME=Wizard Front End"
    when /^GAME=/
      line = "GAME=WIZ"
    when /^GAMEHOST=/
      sline = line.split("=")
      @game[ 'host' ] = sline[ 1 ]
      line = "GAMEHOST=127.0.0.1"
    when /^GAMEPORT=/
      sline = line.split("=")
      @game[ 'port' ] = sline[ 1 ]
    when /^KEY=/
      sline = line.split("=")
      @game[ 'key' ] = sline[ 1 ]
    else
  end
  sal_file += "#{line}\n" ;
}
sal_out = dir [ 'character' ] + "/connect.sal"
File.write( sal_out , sal_file )
fp.close

if @game[ 'host' ].empty? 
  puts "Missing game host"
  exit
end

if @game[ 'port' ].empty? 
  puts "Missing game port"
  exit
end

# Connect to game server...
fp = TCPSocket.new @game [ 'host' ] , @game [ 'port' ]
fp.send "#{@game [ 'key' ]}\n" , 0 
buf = fp.gets.strip

client_announce = '/FE:PLAYRB /VERSION:' + version
if type == 'XML'
  client_announce = "/FE:WIZARD /VERSION:1.0.1.22 /P:i386-mingw32 /XML\n"
end
fp.send "#{client_announce}\n" , 0 
buf = fp.gets.strip

wait = "<c>\r\n"
fp.send "#{wait}\n" , 0
sleep(1)
fp.send "#{wait}\n" , 0

# socket_set_nonblock ( $socket ) ;
# stream_set_blocking ( STDIN , 0 ) ;

@gameArrayLocal = {}
@gameArrayLocal [ 'type' ] = type ;
@gameArrayLocal [ 'game_code' ] = game_code ;

# // autostart
# $autostart_file = $dir [ 'character' ] . "/autostart.txt" ;
# if ( file_exists ( $autostart_file ) )
# {
# 	if ( $autostart_list = file ( $autostart_file ) )
# 	{
# 		foreach ( $autostart_list as $autostart_no => $autostart_script )
# 		{
# 			$autostart_script = trim ( $autostart_script ) ;
# 			print "AUTOSTART SCRIPT: '" . $autostart_script . "'\n"  ;
# 			$script = $dir [ 'scripts' ] . "/" . $autostart_script . ".php" ;
# 			if ( ! ( file_exists ( $script ) ) )
# 			{
# 				print "SCRIPT NOT AVAILABLE: " . $script . "\n" ;
# 			}
# 			elseif ( ! ( include_once ( $script ) ) )
# 			{
# 				print "SCRIPT NOT INCLUDED: " . $script . "\n" ;
# 			}
# 			else
# 			{
# 				if ( isset ( $class_list [ $autostart_script ] ) )
# 				{
# 					print "SCRIPT ALREADY RUNNING: " . $script . "\n" ;
# 				}
# 				else
# 				{
# 					if ( ! ( $class_list [ $autostart_script ] = new $autostart_script ( $socket , $dir ) ) )
# 					{
# 						print "SCRIPT NOT INITIALIZED: " . $script . "\n" ;
# 						unset ( $class_list [ $autostart_script ] ) ;
# 					}
# 				}
# 			}
# 		}
# 	}
# }

done_init = false
time_start = Time.now.to_i

while true
  puts "hi"
# 	if ( ( time ( ) - $time_start ) >= $time_out )
# 	{
# 		break 1 ;
# 	}
# 	if ( $done_init )
# 	{
# 		if ( isset ( $class_list ) )
# 		{
# 			foreach ( $class_list as $class => $class_info )
# 			{
# 				if ( class_exists ( $class ) )
# 				{
# 					if ( is_callable ( array ( $class , 'tick' ) ) )
# 					{
# 						$class_return = $class_list [ $class ] -> tick ( $gameArray ) ;
# 						if ( isset ( $class_return [ 'gameArray' ] ) )
# 						{
# 							$gameArray = $class_return [ 'gameArray' ] ;
# 						}
# 						if ( isset ( $class_return [ 'output' ] ) )
# 						{
# 							$output = $class_return [ 'output' ] ;
# 							print $output ;
# 							$output = '' ;
# 						}
# 					}
# 				}
# 			}
# 		}
# 	}
# 	if ( $background )
# 	{
# 	}
# 	else
# 	{

##  input_stream = $stdin.gets.chomp
#  input_stream = $stdin.read_nonblock(1024).chomp
# PHP: 		$input_stream = fgetcsv ( STDIN ) ;
#  single = input_stream.split(',')
#  if single.size > 1
#    puts single
#  end
# 		if ( is_array ( $input_stream ) )
# 		{
# 			print "--------------------------------------------------------------------------------\n" ;
# 			if ( preg_match ( "/^;/" , $input_stream [ 0 ] ) )
# 			{
# 				$input_split = preg_split ( "/\ /" , preg_replace ( "/^;/" , "" , $input_stream [ 0 ] ) ) ;
# 				if ( strtoupper ( $input_split [ 0 ] ) == 'HELP' )
# 				{
# 					print "To start a script: ';scriptname'\n" ;
# 					print "To unload a script: ';UNLOAD scriptname' -- UNLOADing a script will not allow changes when restarting the script.\n" ;
# 					print "To show running scripts: ';SHOW RUNNING'\n" ;
# 					print "\n" ;
# 					print "Changes to scripts will only take effect after restarting play.php\n" ;
# 				}
# 				elseif ( strtoupper ( $input_split [ 0 ] ) == 'UNLOAD' )
# 				{
# 					if ( isset ( $class_list [ $input_split [ 1 ] ] ) )
# 					{
# 						unset ( $class_list [ $input_split [ 1 ] ] ) ;
# 						if ( ! ( isset ( $class_list [ $input_split [ 1 ] ] ) ) )
# 						{
# 							print "SCRIPT UNLOADED: " . $input_split [ 1 ] . "\n" ;
# 						}
# 					}
# 				}
# 				elseif ( strtoupper ( $input_split [ 0 ] ) == 'SHOW' )
# 				{
# 					if ( strtoupper ( $input_split [ 1 ] ) == 'RUNNING' )
# 					{
# 						if ( isset ( $class_list ) )
# 						{
# 							if ( count ( $class_list ) ) 
# 							{
# 								print "Scripts Running:\n" ;
# 								foreach ( $class_list as $class_name => $class_info )
# 								{
# 									print $class_name . "\n" ;
# 								}
# 							}
# 							else
# 							{
# 								print "No scripts currently running.\n" ;
# 								unset ( $class_list ) ;
# 							}
# 						}
# 						else
# 						{
# 							print "No scripts currently running.\n" ;
# 						}
# 					}
# 				}
# 				else
# 				{
# 					print "RUNNING SCRIPT: '" . $input_stream [ 0 ] . "'\n"  ;
# 					$script_name = preg_split ( "/\ / " , preg_replace ( "/^;/" , "" , $input_stream [ 0 ] ) ) ;
# 					if ( isset ( $script_name [ 0 ] ) )
# 					{
# 						if ( ! ( empty ( $script_name [ 0 ] ) ) )
# 						{
# 							$script = $dir [ 'scripts' ] . "/" . $script_name [ 0 ] . ".php" ;
# 							if ( ! ( file_exists ( $script ) ) )
# 							{
# 								print "SCRIPT NOT AVAILABLE: " . $script . "\n" ;
# 							}
# 							elseif ( ! ( include_once ( $script ) ) )
# 							{
# 								print "SCRIPT NOT INCLUDED: " . $script . "\n" ;
# 							}
# 							else
# 							{
# 								if ( isset ( $class_list [ $script_name [ 0 ] ] ) )
# 								{
# 									print "SCRIPT ALREADY RUNNING: " . $script . "\n" ;
# 								}
# 								else
# 								{
# 									if ( ! ( $class_list [ $script_name [ 0 ] ] = new $script_name [ 0 ] ( $socket , $dir ) ) )
# 									{
# 										print "SCRIPT NOT INITIALIZED: " . $script . "\n" ;
# 										unset ( $class_list [ $script_name [ 0 ] ] ) ;
# 									}
# 									if ( is_callable ( array ( $class_list [ $script_name [ 0 ] ] , 'init' ) ) )
# 									{
# 										$class_list [ $script_name [ 0 ] ] -> init ( $socket ) ;
# 									}
# 								}
# 							}
# 						}
# 					}
# 				}
# 			}
# 			else
# 			{
# 				print "COMMAND: '" . $input_stream [ 0 ] . "'\n"  ;
# 				$input_user = "<c>" . $input_stream [ 0 ] . "\r\n" ;
# 				if ( isset ( $class_list ) )
# 				{
# 					foreach ( $class_list as $class => $class_info )
# 					{
# 						if ( class_exists ( $class ) )
# 						{
# 							if ( is_callable ( array ( $class , 'socket_write' ) ) )
# 							{
# 								$class_return = $class_list [ $class ] -> socket_write ( $input_user ) ;
# 							}
# 						}
# 					}
# 				}
# 				if ( socket_write ( $socket , $input_user , strlen ( $input_user ) ) )
# 				{
# 					$input_history [ ] = $input_user ;
# 				}
# 				switch ( strtoupper ( $input_stream [ 0 ] ) )
# 				{
# 					case 'EXIT' :
# 						break 2 ;
# 					default :
# 				}
# 			}
# 		}
# 	}
      if buf = fp.gets.strip
        puts buf
      end
# 	if ( $buf = socket_read ( $socket , 65536 , PHP_BINARY_READ ) )
# 	{
# 		$time_start = time ( ) ;
# 		if ( preg_match ( "/Invalid login key.  Please relogin to the web site./i" , $buf ) )
# 		{
# 			print date ( "Y-m-d H:i:s" ) . ": Game Host Down\n" ;
# 			break ;
# 		}
# 		if ( preg_match ( "/\<\!-- CLIENT --\>.*\<\!-- ENDCLIENT --\>/i" , $buf ) )
# 		{
# 			print date ( "Y-m-d H:i:s" ) . ": Game Host Down\n" ;
# 			break ;
# 		}
# 		$output = $buf ;
# 		if ( isset ( $class_list ) )
# 		{
# 			foreach ( $class_list as $class => $class_info )
# 			{
# 				if ( class_exists ( $class ) )
# 				{
# 					if ( is_callable ( array ( $class , 'socket_read' ) ) )
# 					{
# 						$class_return = $class_list [ $class ] -> socket_read ( $gameArray , $buf ) ;
# 						if ( isset ( $class_return [ 'gameArray' ] ) )
# 						{
# 							$gameArray = $class_return [ 'gameArray' ] ;
# 						}
# 						if ( isset ( $class_return [ 'output' ] ) )
# 						{
# 							if ( ! ( empty ( $class_return [ 'output' ] ) ) )
# 							{
# 								if ( ! ( isset ( $output ) ) )
# 								{
# 									$output = '' ;
# 								}
# 								$output = $class_return [ 'output' ] ;
# 								// print __LINE__ . ": " .  $class . ": " . $output . "\n" ;
# 							}
# 						}
# 					}
# 				}
# 			}
# 		}
# 
# 		if ( ! ( $done_init ) )
# 		{
# 			if ( preg_match ( "/Important Information/i" , $buf ) )
# 			{
# 				if ( isset ( $class_list ) )
# 				{
# 					foreach ( $class_list as $class => $class_info )
# 					{
# 						if ( class_exists ( $class ) )
# 						{
# 							if ( is_callable ( array ( $class , 'init' ) ) )
# 							{
# 								$class_list [ $class ] -> init ( $socket ) ;
# 							}
# 						}
# 					}
# 				}
# 				$done_init = TRUE ;
# 			}
# 		}
# 
# 		if ( ! ( $background ) )
# 		{
# 			if ( ! ( empty ( $output ) ) )
# 			{
# 				print $output ;
# 				unset ( $output ) ;
# 			}
# 			elseif ( ! ( empty ( $buf ) ) )
# 			{
# 				print $buf ;
# 			}
# 			$buf = '' ;
# 		}
# 	}
  break 
end

fp.close
exit
