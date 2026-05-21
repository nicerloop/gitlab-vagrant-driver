class GitlabVagrantDriver < Formula
  desc "Custom GitLab Runner driver that provisions CI jobs in Vagrant VMs"
  homepage "https://github.com/nicerloop/gitlab-vagrant-driver"
  url "https://github.com/nicerloop/gitlab-vagrant-driver/archive/refs/tags/0.0.2.tar.gz"
  sha256 "b18335a3ae732fc3cf265d25401daa8a3c479cad770e8119438c99b359a8717c"
  license "MIT"

  def install
    bin.install "bin/gitlab-vagrant-driver"
    share.install "share/templates" => "gitlab-vagrant-driver"
  end

  test do
    system bin/"gitlab-vagrant-driver", "help"
  end
end
