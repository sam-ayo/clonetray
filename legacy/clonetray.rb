class Clonetray < Formula
  desc "Menu bar app that clones Git repos and opens them in your IDE"
  homepage "https://github.com/sam-ayo/clonetray"
  url "file:///tmp/clonetray-build/clonetray-0.1.0.tar.gz"
  version "0.1.0"
  sha256 "fc6c97e4cac6c28a00d396909c9a190cd38e89a848029f369b6c6c9dedc0a5cb"

  head "https://github.com/sam-ayo/clonetray.git", branch: "main"

  depends_on "python@3.11"

  def install
    venv = virtualenv_create(libexec, "python3.11")
    system libexec/"bin/pip", "install", "--quiet",
           "gitpython>=3.1.44", "rumps>=0.4.0", "pyyaml>=6.0"

    libexec.install "tray_clone.py", "config.yml"

    (bin/"clonetray").write <<~EOS
      #!/bin/bash
      exec "#{libexec}/bin/python" "#{libexec}/tray_clone.py" "$@"
    EOS
    chmod 0755, bin/"clonetray"
  end

  service do
    run [opt_bin/"clonetray"]
    keep_alive true
    log_path var/"log/clonetray.log"
    error_log_path var/"log/clonetray.log"
    process_type :interactive
  end

  test do
    assert_predicate libexec/"tray_clone.py", :exist?
    assert_predicate bin/"clonetray", :executable?
  end
end
