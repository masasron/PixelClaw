class Pixelclaw < Formula
  desc "Tiny pixel crab that lives on your Dock"
  homepage "https://github.com/masasron/PixelClaw"
  url "https://github.com/masasron/PixelClaw/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "699fb9f386f2195b173a3835887e63887f165921c2a342b9b1fdfaebbe2e09fd"
  license "MIT"

  depends_on macos: :monterey
  depends_on xcode: ["15.0", :build]

  def install
    system "swift", "build", "--disable-sandbox", "-c", "release"

    bin.install ".build/release/PixelClaw" => "pixelclaw"
    bin.install Dir[".build/release/PixelClaw_PixelClaw.bundle"]
  end

  test do
    assert_predicate bin/"pixelclaw", :exist?
    assert_predicate bin/"PixelClaw_PixelClaw.bundle", :exist?
  end
end
