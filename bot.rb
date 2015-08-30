require 'cinch'
require './cinch-playcode/lib/cinch/plugins/codegame'

bot = Cinch::Bot.new do

  configure do |c|
    c.nick            = "codenamesbot"
    c.server          = "chat.freenode.net"
    c.channels        = ["#playcode"]
    c.verbose         = true
    c.plugins.plugins = [
        Cinch::Plugins::CodeGame
    ]
    c.plugins.options[Cinch::Plugins::CodeGame] = {
        :mods     => ["contig"],
        :channel  => "#playcode",
    }
  end

end

bot.start
