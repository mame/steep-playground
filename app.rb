require "sinatra/base"
require "json"
require "steep"
require "steep/cli"
require "pathname"
require "stringio"
require "dalli"
require "tmpdir"

class SteepPlayground < Sinatra::Base
  if ENV["RACK_ENV"] == "production"
    set :cache, Dalli::Client.new
  else
    DummyCache = {}
    class << DummyCache
      alias get []
      alias set []=
    end
    set :cache, DummyCache
  end

  get "/" do
    send_file File.join(__dir__, "docs/index.html")
  end

  if ENV["RACK_ENV"] == "production"
    get "/main.js" do
      send_file File.join(__dir__, "docs/main.js")
    end
  else
    get "/main.js" do
      content_type "application/javascript"
      File.read(File.join(__dir__, "docs/main.js"))#.sub("https://aluminium.ruby-lang.org/steep-playground", "")
    end
  end

  get "/style.css" do
    send_file File.join(__dir__, "docs/style.css")
  end

  MAX_SIZE = 2000

  post "/analyze" do
    req = request.body.read

    cache_key = "steep-playground:" + req

    res = settings.cache.get(cache_key)
    return res if res

    req = JSON.parse(req)

    rb_text = req["rb"] || ""
    rbs_text = req["rbs"] || ""

    if rb_text.size > MAX_SIZE || rbs_text.size > MAX_SIZE
      return JSON.generate({
        status: "error",
        message: "The input is too long",
      })
    end

    p req

    output = Dir.mktmpdir do |dir|
      File.write(File.join(dir, "Steepfile"), <<-END)
target :test do
  signature "."
  check "test.rb"
end
      END

      File.write(File.join(dir, "test.rb"), rb_text)
      File.write(File.join(dir, "test.rbs"), rbs_text)

      system("ls #{ dir }")

      out = StringIO.new
      Steep::CLI.new(argv: ["check", "--steepfile=#{ dir }/Steepfile"], stdout: out, stderr: out, stdin: nil).run
      out.string
    end

    output = output.gsub(/\e\[[\d;]*m/, "")
    output << "\n\n"
    output << "## Version info:\n"
    output << "##   * Ruby: #{ RUBY_VERSION }\n"
    output << "##   * RBS: #{ RBS::VERSION }\n"
    output << "##   * Steep: #{ Steep::VERSION }\n"

    res = {
      status: "ok",
      output: output,
    }

    res = JSON.generate(res)

    settings.cache.set(cache_key, res)

    res

  rescue SyntaxError, RBS::Parser::SyntaxError => exc
    res = {
      status: "error",
      message: "#{ exc.message }",
    }

    JSON.generate(res)
  end
end
