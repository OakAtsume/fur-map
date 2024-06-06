require_relative("src/barq")
barq = BarqWrapping.new
i = 0


loop do
  a = barq.homepage(i, limit: 50)
  puts a
  puts JSON.pretty_generate(a)

  size = a["data"]["profiles"].size

  def saveRecord(uuid, name, type, region, long, lat)
    File.open("records.txt", "a") do |file|
      file.puts("#{uuid},#{name},#{type},#{region},#{lat},#{long}")
    end
  end

  for i in 0..size - 1
    instance = a["data"]["profiles"][i]
    puts("Name: #{instance["displayName"]} - UUID: #{instance["uuid"]}")
    puts("Location: #{instance["location"]["distance"]} - Type: #{instance["location"]["type"]}")
    begin
      fetch = barq.user(instance["uuid"])
      if !fetch["errors"].nil?
        msg = fetch["errors"][0]["message"]
        puts("Error: #{msg}")
        # Too many requests, please try again in 6 seconds (#177040)
        time_to_sleep = msg.scan(/in (\d+) seconds/).flatten[0].to_i
        puts("Sleeping for #{time_to_sleep} seconds")
        sleep(time_to_sleep)
        fetch = barq.user(instance["uuid"])
      end
      puts("Location of #{instance["displayName"]}: #{fetch["data"]["profile"]["location"]})")
      #puts("Data For #{instance["displayName"]}: #{barq.user(instance["uuid"])}")
      saveRecord(instance["uuid"], instance["displayName"], instance["location"]["type"], fetch["data"]["profile"]["location"]["place"]["region"], fetch["data"]["profile"]["location"]["place"]["longitude"], fetch["data"]["profile"]["location"]["place"]["latitude"])
      sleep 1
    rescue => e
      puts("Error: #{e}")
      puts fetch
    end
  end
  i += 50
end
