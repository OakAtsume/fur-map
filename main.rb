require_relative("src/barq")
require_relative("src/log")
barq = BarqWrapping.new
logo

# Check if where currently Logged in #
user = barq.localuser
if user.nil? || user.has_key?("error")
  log(level: :warn, message: "Not logged in or expired session, please consider running with the --login flag.")
else
  # puts user

  log(level: :info, message: "Logged in as #{user["nickname"]} : #{user["gender"]}")
end

arguments = {}
ARGV.each do |arg|
  if arg.start_with?("--")
    arg = arg.split("=")
    arguments[arg[0].gsub("--", "")] = arg[1]
  end
end
ARGV.clear # Clear the arguments so we don't get any errors.

if arguments.has_key?("login")
  # Login Methods: 0 = QRCode, 1 = Email + Verification Code.
  # Check if way was provided.
  if arguments["login"].nil?
    log(level: :error, message: "Please provide a way to login.\n --login=0 for QRCode\n --login=1 for Email + Verification Code")
    exit 1
  end
  way = arguments["login"].to_i
  if way != 0 && way != 1
    log(level: :error, message: "Invalid login method provided. Please provide a valid method.")
    exit 1
  end
  log(level: :info, message: "Starting login process with method: #{way}")
  case way
  when 0
    log(level: :info, message: "Starting login process Via QR-Code. Please have your phone ready.")
    barq.qrLogin
  when 1
    if arguments["email"].nil?
      log(level: :error, message: "Please provide an email address to login. (+ --email=<email>)")
      exit 1
    end
    email = arguments["email"]
    log(level: :info, message: "Starting login process Via Email. Please check your email for the verification code.")
    barq.login(email)
  end
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
      ["--output", "Output the results to a file (default random /tmp/ file)", "--output=results.json"],
    ]
  )
  exit 0
end

if arguments.has_key?("find")
  username = arguments["find"]
  limit = arguments.has_key?("limit") ? arguments["limit"].to_i : 100 # Default limit is 100
  lewd = arguments.has_key?("lewd") ? true : false
  log(level: :info, message: "Searching for user: #{username}")
  results = barq.find(username, isLewd: lewd, limit: limit)
  #puts results

  if results.nil? || results.empty?
    log(level: :warn, message: "No results found for user: #{username}")
  else
    if results["data"]["profileSearch"].empty?
      log(level: :warn, message: "No results found for user: #{username}")
    else
      log(level: :info, message: "Found #{results["data"]["profileSearch"].length} results for user: #{username}")
      puts hashToTable(
        ["UUID", "Username"],
        results["data"]["profileSearch"].map { |x| [x["uuid"], x["displayName"]] }
      )
    end
  end
  exit 0
end

if arguments.has_key?("user")
  uuid = arguments["user"]
  log(level: :info, message: "Retrieving user information for UUID: #{uuid}")
  user = barq.user(uuid)
  if user.nil? || user.has_key?("error")
    log(level: :warn, message: "No user found for UUID: #{uuid}")
    exit 1
  else
    log(level: :info, message: "User information for UUID: #{uuid} .. Please wait while I parse")
  end
  # puts user

  user = user["data"]["profile"]
  # Top Level User Information
  puts hashToTable(
    ["ID", "Username", "Has NSFW", "Age"],
    [
      [user["uuid"], user["displayName"], user["isAdOptIn"], user["age"]],
    ]
  )

  # Privacy Information
  puts hashToTable(
    ["Chat Policy", "Age Policy", "NSFW Policy", "Kinks Policy", "Disallow NSFW", "Disallow Minors", "Show Last Online"],
    [
      [user["privacySettings"]["startChat"], user["privacySettings"]["viewAge"], user["privacySettings"]["viewAd"], user["privacySettings"]["viewKinks"], user["privacySettings"]["blockAdults"], user["privacySettings"]["blockMinors"], user["privacySettings"]["showLastOnline"]],
    ]
  )
  # Location Information
  puts hashToTable(
    ["Type", "Distance", "Place", "Region", "Country", "Latitude", "Longitude"],
    [
      [
        user["location"]["type"],
        user["location"]["distance"],
        user["location"]["place"]["place"],
        user["location"]["place"]["region"],
        user["location"]["place"]["countryCode"],
        user["location"]["place"]["latitude"],
        user["location"]["place"]["longitude"],
      ],
    ]
  )

  # Bio #
  puts " " * 80
  puts hashToTable(
    ["Bio", "Genders", "Languages", "Relationship Status", "Sexual Orientation", "Intrests", "Hobbies"],
    [
      [
        user["bio"]["biography"].gsub("\n", " "),
        user["bio"]["genders"].nil? ? "None" : user["bio"]["genders"].join(", "),
        user["bio"]["languages"].nil? ? "None" : user["bio"]["languages"].join(", "),
        user["bio"]["relationshipStatus"],
        user["bio"]["sexualOrientation"],
        user["bio"]["interests"].nil? ? "None" : user["bio"]["interests"].join(", "),
        user["bio"]["hobbies"].nil? ? "None" : user["bio"]["hobbies"].map { |x| x["interest"] }.join(", "),
      ],
    ]
  )

  # Sonas #

  hash = []
  user["sonas"].each do |sona|
    hash.push([sona["displayName"],
               sona["description"],
               sona["hasFursuit"],
               sona["species"]["displayName"]])
  end
  puts hashToTable(
    ["Name", "Description", "Has Fursuit?", "Specie(s)"],
    hash
  )

  if !user["bioAd"].nil?

    # Lewd Information #
    puts hashToTable(
      ["Biography", "Sex Positions", "Behavior", "Safe Sex?", "can host"],
      [
        [
          user["bioAd"]["biography"],
          user["bioAd"]["sexPositions"].nil? ? "None" : user["bioAd"]["sexPositions"].join(", "),
          user["bioAd"]["behaviour"].nil? ? "None" : user["bioAd"]["behaviour"].join(", "),
          user["bioAd"]["safeSex"],
          user["bioAd"]["canHost"].nil? ? "None" : user["bioAd"]["canHost"].to_s, # I don't know what goes here so it's a place holder

        ],
      ]
    )
  end

  if !user["kinks"].nil?
    # Kinks #
    hash = []
    user["kinks"].each do |kink|
      hash.push([
        kink["kink"]["displayName"],
        kink["kink"]["isVerified"],
        kink["kink"]["isSinglePlayer"],
      ])
    end
    puts hashToTable(
      ["Kink", "Verified?", "Single Player?"],
      hash
    )
  end

  # Social Medias #
  hash = []
  user["socialAccounts"].each do |social|
    hash.push([
      social["socialNetwork"], # Social Network (Discord, Twitter, etc)
      social["displayName"], # Username
      social["value"], # Tag
      social["isVerified"], # Verified?
      social["url"], # URL
    ])
  end
  puts hashToTable(
    ["Social Network", "Username", "Tag", "Verified?", "URL"],
    hash
  )

  # Groups #
  hash = []
  user["groups"].each do |group|
    hash.push([
      group["group"]["displayName"],
      group["group"]["isAd"],
      group["group"]["contentRating"],
    ])
  end
  puts hashToTable(
    ["Group", "Is Lewd", "Content Rating"],
    hash
  )
  # Events #
  hash = []
  user["events"].each do |event|
    hash.push([
      event["event"]["displayName"],
      event["event"]["isAd"],
      event["event"]["contentRating"],

      event["event"]["eventBeginAt"],
      event["event"]["eventEndAt"],
    ])
  end
  puts hashToTable(
    ["Event", "Is Lewd", "Content Rating", "Start Date", "End Date"],
    hash
  )
  exit 0
end
