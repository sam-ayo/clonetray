cask "clonetray" do
  version "0.2.0"
  # Replace with the checksum `make dmg` prints for the released disk image.
  sha256 :no_check

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
