class GitlabVagrantDriver < Formula
  desc "Custom GitLab Runner driver that provisions CI jobs in Vagrant VMs"
  homepage "https://github.com/nicerloop/gitlab-vagrant-driver"
  url "https://github.com/nicerloop/gitlab-vagrant-driver/archive/refs/tags/0.0.3.tar.gz"
  sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  license "MIT"

  def install
    bin.install "bin/gitlab-vagrant-driver"
    share.install "share/templates" => "gitlab-vagrant-driver"
  end

  test do
    system bin/"gitlab-vagrant-driver", "help"
  end
end
