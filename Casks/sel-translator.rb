cask "sel-translator" do
  version "0.1.4"
  sha256 "d18baaf36ae7196dafd010266a17066f0e49e27a1f3d1efbca1a1fa497090ece"

  url "https://github.com/TeoBale/SelTranslator/releases/download/v#{version}/SelTranslator-macos.zip"
  name "SelTranslator"
  desc "Global selected-text translator for macOS"
  homepage "https://github.com/TeoBale/SelTranslator"

  app "SelTranslator.app"
end
