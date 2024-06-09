require("net/http")
require("rqrcode")
require("base64")
require("json")
require_relative("log") # src/log.rb

class BarqWrapping
  def initialize(configFile = "config.json")
    @api = {
      id: "https://id.barq.app",
      api: "https://api.barq.app",
      web: "https://web.barq.app",
    }
    @useragent = "BarqWrapping/0.1.0"
    @configPath = configFile
    @config = config(@configPath)
  end

  def qrLogin
    intial = URI("#{@api[:id]}/auth?client_id=barq-web&redirect_uri=https%3A%2F%2Fweb.barq.app%2Flogin%2Fcallback&response_type=code&state=%2F&scope=openid%20profile%20offline_access&prompt=consent") # This is the initial login page
    redir = get(intial)
    cookies = redir.get_fields("set-cookie").join("; ")
    interactionID = redir.body.scan(/Redirecting to <a href="\/interaction\/(.+?)">/).flatten[0]
    redir = URI("#{@api[:id]}/interaction/#{interactionID}")
    redir = get(redir, { "Cookie" => cookies })
    qrToken = redir.body.scan(/fetch\('\/app\/auth\/(.+?)'\)/).flatten[0]
    log(level: :info, message: "Interaction ID: #{interactionID}")
    qr(qrToken)
    log(level: :info, message: "Please scan the QR code above to login.")
    checkUri = URI("#{@api[:id]}/app/auth/#{qrToken}")
    totalPolls = 0
    loop do
      sleep(2.4)
      check = get(checkUri, { "Cookie" => cookies })
      totalPolls += 1
      if check.body == "true"
        log(level: :info, message: "Authentication request approved by Host.")
        break
      elsif check.body == "false"
        log(level: :error, message: "Authentication request denied by Host.")
        exit 1
      end
    end
    log(level: :info, message: "Total Polls: #{totalPolls} : #{totalPolls * 2.4} seconds.")
    log(level: :info, message: "Starting callback authentication process... (This may take a while.)")
    callbackLogin = URI("#{@api[:id]}/interaction/#{qrToken}/login")
    loginReq = get(callbackLogin, { "Cookie" => cookies })
    loginLocation = loginReq.get_fields("location")[0].gsub("http", "https")
    loginUri = URI(loginLocation)
    loginReq = get(loginUri, { "Cookie" => cookies })
    cookies = loginReq.get_fields("set-cookie").join("; ")
    loginUri = URI("#{@api[:id]}#{loginReq.get_fields("location")[0].gsub("http", "https")}")
    loginReq = get(loginUri, { "Cookie" => cookies })
    # puts loginReq.body
    interactionid = loginReq.body.scan(/interaction\/(.+?)\/confirm/).flatten[0]
    if interactionid.nil? || interactionid.empty?
      log(level: :error, message: "No interaction ID found! Please create an issue on the GitHub repository!!")
      exit 1
    end
    log(level: :info, message: "Got (#{interactionid}) Starting confirmation process...")
    # Send the confirmation #
    # /interaction/:interaction_id/confirm>
    # MOST ERRORS WILL COME FROM HERE!!! #

    confirmUri = URI("#{@api[:id]}/interaction/#{interactionid}/confirm")
    confirmReq = post(confirmUri, { "Cookie" => cookies })
    log(level: :info, message: "Confirmation request sent... attempting to retrieve token and cookie.")
    ##########################3
    log(message: "Starting Thrid stage...")
    initial = URI("#{confirmReq.get_fields("location")[0].gsub("http", "https")}")
    req = get(initial, { "Cookie" => cookies })
    cookies = req.get_fields("set-cookie").join("; ")

    location = req.get_fields("location")[0].gsub("http", "https")
    initial = URI(location)
    # puts intial
    # puts initial.query

    code = initial.query.scan(/code=(.+?)&/).flatten[0]

    if code.nil? || code.empty?
      log(level: :error, message: "Unable to retreat Code.. Please create a Github Issue!!")
      exit 1
    end
    log(message: "Obtained final code: #{code} finally retreating token")
    token = URI("#{@api[:id]}/token")
    tokenReq = Net::HTTP::Post.new(token)
    tokenReq["User-Agent"] = @useragent
    tokenReq["Authorization"] = "Basic #{Base64.strict_encode64("barq-web:barq-web-password")}"
    tokenReq.set_form_data({
      code: code,
      grant_type: "authorization_code",
      redirect_uri: "https://web.barq.app/login/callback",
    })
    response = Net::HTTP.start(token.hostname, token.port, use_ssl: true) do |http|
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      http.request(tokenReq)
    end
    # puts response.body

    codes = JSON.parse(response.body)
    log(level: :info, message: "Token: #{codes["access_token"]}")
    log(level: :info, message: "Cookie: #{cookies}")
    @config["token"] = codes["access_token"]
    @config["cookie"] = cookies
    # puts @config
    # puts @configPath

    File.write(@configPath, JSON.pretty_generate(@config))
  end

  def login(email)
    # Check that email is valid

    uri = URI("#{@api[:api]}/account-provider/email/request-code")
    payload = { "email": email }.to_json
    res = post(uri, { "Content-Type" => "application/json" }, data: payload)
    log(level: :info, message: "Email sent to #{email} with verification code.")
    log(level: :info, message: "Please provide the verification code below.")
    print("Verification Code: ")
    code = gets.chomp
    code = code.upcase
    uri = URI("#{@api[:api]}/account-provider/email/login")
    payload = { "email": email, "code": code }.to_json
    res = post(uri, { "Content-Type" => "application/json" }, data: payload)
    # Check if body is JSON.
    if res.body.start_with?("{")
      reply = JSON.parse(res.body)
      if reply.has_key?("error")
        log(level: :error, message: reply["message"])
        exit 1
      end
    end
    # puts res.body
    # puts res.body

    log(level: :info, message: "Logged in successfully.")
    @config["token"] = res.body.gsub("\"", "")
    @config["cookie"] = ""
    File.write(@configPath, JSON.pretty_generate(@config))
  end

  def localuser
    uri = URI("#{@api[:id]}/me")
    res = get(uri, { "Content-Type" => "application/json" }, authed: true)
    return JSON.parse(res.body)
  end

  def find(username, isLewd: false, limit: 15)
    uri = URI("#{@api[:api]}/graphql")
    payload =
      {
        "operationName": "ProfileSearch",
        "variables": {
          "cursor": "0",
          "filters": {
            "displayName": username,
          },
          "isAd": isLewd,
        },
        "query": "query ProfileSearch($filters: ProfileSearchFiltersInput!, $cursor: String = \"0\", $isAd: Boolean) {\n  profileSearch(filters: $filters, cursor: $cursor, limit: #{limit}, isAd: $isAd) {\n    uuid\n    displayName\n    profileImage(isAd: $isAd) {\n      id\n      image {\n        ...UploadedImage\n        __typename\n      }\n      __typename\n    }\n    roles\n    __typename\n  }\n}\n\nfragment UploadedImage on UploadedImage {\n  uuid\n  url\n  isExplicit\n  contentRating\n  height\n  width\n  __typename\n}",
      }
    res = post(uri, { "Content-Type" => "application/json" }, data: payload.to_json, authed: true)
    return JSON.parse(res.body)
  end

  def user(uuid, isLewd: false)
    uri = URI("#{@api[:api]}/graphql")
    payload = {
      "operationName": "ProfileDetail",
      "variables": {
        "uuid": uuid,
        "isAd": isLewd,
      },
      "query": "query ProfileDetail($uuid: String!, $isAd: Boolean, $location: SearchLocationInput) {\n  profile(uuid: $uuid, location: $location) {\n    id\n    uuid\n    displayName\n    relationType\n    isAdOptIn\n    isBirthday\n    age\n    profileImage(isAd: $isAd) {\n      id\n      image {\n        ...UploadedImage\n        __typename\n      }\n      __typename\n    }\n    privacySettings {\n      ...PrivacyFragment\n      __typename\n    }\n    images {\n      id\n      image {\n        ...UploadedImage\n        __typename\n      }\n      isAd\n      likeCount\n      hasLiked\n      accessPermission\n      __typename\n    }\n    location {\n      type\n      distance\n      place {\n        place\n        region\n        countryCode\n        longitude\n        latitude\n        __typename\n      }\n      __typename\n    }\n    bio {\n      biography\n      genders\n      languages\n      relationshipStatus\n      sexualOrientation\n      interests\n      hobbies {\n        id\n        interest\n        __typename\n      }\n      socialAccounts {\n        ...SocialAccountsFragment\n        __typename\n      }\n      __typename\n    }\n    bioAd {\n      biography\n      sexPositions\n      behaviour\n      safeSex\n      canHost\n      __typename\n    }\n    sonas {\n      id\n      displayName\n      images {\n        id\n        __typename\n      }\n      description\n      hasFursuit\n      species {\n        id\n        displayName\n        __typename\n      }\n      __typename\n    }\n    kinks {\n      kink {\n        id\n        displayName\n        categoryName\n        isVerified\n        isSinglePlayer\n        __typename\n      }\n      pleasureReceive\n      pleasureGive\n      __typename\n    }\n    groups {\n      group {\n        uuid\n        displayName\n        isAd\n        contentRating\n        image {\n          ...UploadedImage\n          __typename\n        }\n        __typename\n      }\n      threadCount\n      replyCount\n      __typename\n    }\n    events {\n      event {\n        uuid\n        displayName\n        isAd\n        contentRating\n        eventBeginAt\n        eventEndAt\n        image {\n          ...UploadedImage\n          __typename\n        }\n        __typename\n      }\n      isWaitingList\n      __typename\n    }\n    socialAccounts {\n      id\n      socialNetwork\n      isVerified\n      url\n      displayName\n      value\n      accessPermission\n      __typename\n    }\n    roles\n    shareHash\n    __typename\n  }\n}\n\nfragment UploadedImage on UploadedImage {\n  uuid\n  url\n  isExplicit\n  contentRating\n  height\n  width\n  __typename\n}\n\nfragment PrivacyFragment on PrivacySettings {\n  startChat\n  viewAge\n  viewAd\n  viewKinks\n  viewProfile\n  blockAdults\n  blockMinors\n  showLastOnline\n  __typename\n}\n\nfragment SocialAccountsFragment on ProfileSocialAccounts {\n  twitter {\n    value\n    accessPermission\n    __typename\n  }\n  twitterAd {\n    value\n    accessPermission\n    __typename\n  }\n  telegram {\n    value\n    accessPermission\n    __typename\n  }\n  instagram {\n    value\n    accessPermission\n    __typename\n  }\n  steam {\n    value\n    accessPermission\n    __typename\n  }\n  discord {\n    value\n    accessPermission\n    __typename\n  }\n  deviantArt {\n    value\n    accessPermission\n    __typename\n  }\n  furAffinity {\n    value\n    accessPermission\n    __typename\n  }\n  bluesky {\n    value\n    accessPermission\n    __typename\n  }\n  mastodon {\n    value\n    accessPermission\n    __typename\n  }\n  vrChat {\n    value\n    accessPermission\n    __typename\n  }\n  __typename\n}",
    }
    res = post(uri, { "Content-Type" => "application/json" }, data: payload.to_json, authed: true)
    return JSON.parse(res.body)
  end

  private

  def qr(token)
    qr = RQRCode::QRCode.new("barq-auth;#{token}")
    svg = qr.as_ansi(
      light: "\033[47m",
      dark: "\033[40m",
      fill_character: "  ",
      quiet_zone_size: 2,
    )
    puts(svg)
  end

  def get(uri, headers = {}, authed: false)
    req = Net::HTTP::Get.new(uri)

    headers["User-Agent"] = @useragent
    headers["Authorization"] = "Bearer #{@config["token"]}" if authed
    headers["Cookie"] = @config["cookie"] if authed
    headers.each { |k, v| req[k] = v }

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      http.request(req)
    end
    return res
  end

  def post(uri, headers = {}, authed: false)
    req = Net::HTTP::Post.new(uri)

    headers["User-Agent"] = @useragent
    headers["Authorization"] = "Bearer #{@config["token"]}"
    headers["Cookie"] = @config["cookie"]
    headers.each { |k, v| req[k] = v }

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      # Disable SSL verification
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      http.request(req)
    end
    return res
  end

  def post(uri, headers = {}, data: nil, authed: false)
    req = Net::HTTP::Post.new(uri)

    req["User-Agent"] = @useragent
    req["Authorization"] = "Bearer #{@config["token"]}" if authed
    req["Cookie"] = @config["cookie"] if authed
    headers.each { |k, v| req[k] = v }

    req.body = data
    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      http.request(req)
    end
    return res
  end

  def config(file_name)
    if File.exist?(file_name)
      return JSON.parse(File.read(file_name))
    else
      raise("Config file not found!")
      # File.write(file_name, JSON.pretty_generate({}))
      # return {}

    end
  end
end
