cask "clonetray" do
  version "0.2.0"
  sha256 "c14683df86663de9b60384f39cee1fa49f3517541fa106ff561b2c45d9b7a5eb"

  url "https://github.com/sam-ayo/clonetray/releases/download/v#{version}/CloneTray-#{version}.dmg"
  name "CloneTray"
  desc "Menu bar app that clones Git repos and opens them in your IDE"
  homepage "https://github.com/sam-ayo/clonetray"

  depends_on macos: ">= :ventura"

  app "CloneTray.app"

  zap trash: [
    "~/Library/Application Support/CloneTray",
    "~/Library/Preferences/com.sam-ayo.clonetray.plist",
  ]
end
