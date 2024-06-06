def log(level: :info, message: "", code: nil)
  timestamp = Time.now.strftime("%H:%M:%S")
  # [<cyan>timestamp</cyan>] [<green>INFO</green>] message
  case level
  when :info
    puts("[\e[36m#{timestamp}\e[0m] [\e[32m#{level.to_s.upcase}\e[0m] #{message}")
  when :warn
    puts("[\e[36m#{timestamp}\e[0m] [\e[33m#{level.to_s.upcase}\e[0m] #{message}")
  when :error
    puts("[\e[36m#{timestamp}\e[0m] [\e[31m#{level.to_s.upcase}\e[0m] #{message}")
    if code
      puts("  \e[31m#{code}\e[0m")
    end
  when :logo
    puts("[\e[36m#{timestamp}\e[0m] [\e[34m*\e[0m] #{message}")
  when :http
    puts("[\e[36m#{timestamp}\e[0m] [\e[34m#{level.to_s.upcase}\e[0m] #{message} \e[33m#{code}\e[0m")
  end
end

def logo()
#  ______              _     ______                   
# (____  \            | |   (____  \                  
# ____)  ) ____  ____| |  _ ____)  ) ____  ____ ____ 
# |  __  ( / _  |/ ___) | / )  __  ( / _  |/ ___) _  |
# | |__)  | ( | | |   | |< (| |__)  | ( | | |  | | | |
# |______/ \_||_|_|   |_| \_)______/ \_||_|_|   \_|| |
#                                                 |_|

logo = ""
logo += " ______              _     ______                   \n"
logo += "(____  \\            | |   (____  \\                  \n"
logo += "____)  ) ____  ____| |  _ ____)  ) ____  ____ ____ \n"
logo += "|  __  ( / _  |/ ___) | / )  __  ( / _  |/ ___) _  |\n"
logo += "| |__)  | ( | | |   | |< (| |__)  | ( | | |  | | | |\n"
logo += "|______/ \\_||_|_|   |_| \\_)______/ \\_||_|_|   \\_|| |\n"
logo += "                                                |_|\n"


  logo.each_byte do |c|
    # Random color
    r = rand(31..36)
    print("\e[#{r}m#{c.chr}\e[0m")
  end

  log(level: :logo, message: "Welcome to Bark-Barq, this is an unofficial warp/reverse-engineer of the Barq API.")
  log(level: :logo, message: "As such it is not affiliated with the Barq Project in any capacity. (For now ... ?)")
  log(level: :logo, message: "This application allows you to find user's based on a given cordination.")
  # log(level: :logo, message: "Welcome to Bark-Barq, this is an unofficial wrap/reverse-engineer of the Barq API.")
  # log(level: :logo, message: "As such it is not affiliated with the Barq Project in any capacity. (Yet, maybe? I don't mind working with you guys!)")
  # log(level: :logo, message: "I @OakAtsume, do not take any responsibility for any misuse of this tool.")
  # log(level: :logo, message: "Use it responsibly and for good purposes.")
  # log(level: :logo, message: "Enjoy!")

end

def color(color, msg)
  colors = {
    :red => 31,
    :green => 32,
    :yellow => 33,
    :blue => 34,
    :magenta => 35,
    :cyan => 36,
    :bold => 1,
  }
  return "\e[#{colors[color]}m#{msg}\e[0m"
end

def hashToTable(headers, data)
  table = ""
  table += headers.join(" | ") + "\n"
  table += "-" * (headers.join(" | ").length) + "\n"
  data.each do |row|
    table += row.join(" | ") + "\n"
  end
  return table
end