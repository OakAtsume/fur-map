require_relative("src/barq")
require_relative("src/log")
require("tty-prompt")
barq = BarqWrapping.new
logo
prompt = TTY::Prompt.new

# Check if where currently Logged in #
user = barq.localuser
if user.nil? || user.has_key?("error")
  log(level: :warn, message: "Not logged in or expired session, please consider running with the --login flag.")
else
  # puts user
  log(level: :info, message: "Logged in as #{user['nickname']} : #{user['gender']}")
end



arguments = {}
ARGV.each do |arg|
  if arg.start_with?("--")
    arg = arg.split("=")
    arguments[arg[0].gsub("--", "")] = arg[1]
  end
end

if arguments.has_key?("login")
  log(level: :info, message: "Starting login process...")
  barq.autologin
end

if arguments.has_key?("help")
  log(level: :info, message: "Top level commands:")
  puts hashToTable(
    ["Command", "Description", "Example"],
    [
      ["--login", "Start the assisted login process.", "--login"],
      ["--help", "Show this help menu.", "--help"],
      ["--find", "Find a user based on an username", "--find=CatSlayer200_xXx"],
      ["--user", "Retrieve user information based on a user ID", "--user=FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF"],
      ["--me", "Retrieve your own user information", "--me"],
      ["--heatmap", "Start generating a heatmap of users based on a given location", "--heatmap --long=0.000000 --lat=0.000000 --limit=none"],
    ]
  )
  log(level: :info, message: "Sub-option commands:")
  puts hashToTable(
    ["Command", "Description", "Example"],
    [
      ["--lewd", "Toggle lewd mode on/off", "--lewd"],
      ["--long", "Set longtitute", "--long=0.000000"],
      ["--lat", "Set latitude", "--lat=0.000000"],
      ["--limit", "Set the limit of results to display (default 10)", "--limit=10"],
      ["--tree-search", "Enable Tree Spider Search algorithm (See README for more information)", "--tree-search"],
      ["--output", "Output the results to a file (default random /tmp/ file)", "--output=results.json"]
  ]
  )
  exit 0


end
