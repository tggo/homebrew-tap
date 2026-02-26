class WhisperIhm < Formula
  desc "Offline speech-to-text transcription for long audio files"
  homepage "https://github.com/tggo/whisper.ihm"
  url "https://github.com/tggo/whisper.ihm/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "fed4595c1a362c02e3d79d65cee29eacc2d860d3bb9e9f98ab3b29af572f59aa"
  license "MIT"

  depends_on "cmake" => :build
  depends_on "go" => :build
  depends_on :macos

  resource "whisper.cpp" do
    url "https://github.com/ggml-org/whisper.cpp.git",
        branch: "master",
        shallow: true
  end

  resource "ten-vad" do
    url "https://github.com/TEN-framework/ten-vad.git",
        branch: "main",
        shallow: true
  end

  def install
    resource("whisper.cpp").stage(buildpath/"whisper.cpp")
    resource("ten-vad").stage(buildpath/"ten-vad")

    # Build whisper.cpp
    system "cmake", "-S", "whisper.cpp", "-B", "whisper.cpp/build",
           "-DCMAKE_BUILD_TYPE=Release",
           "-DGGML_METAL=ON",
           "-DGGML_METAL_EMBED_LIBRARY=ON",
           "-DBUILD_SHARED_LIBS=OFF"
    system "cmake", "--build", "whisper.cpp/build", "--config", "Release",
           "-j#{ENV.make_jobs}"

    # Build Go binary
    whisper_inc = "#{buildpath}/whisper.cpp/include:#{buildpath}/whisper.cpp/ggml/include"
    whisper_lib = [
      "#{buildpath}/whisper.cpp/build/src",
      "#{buildpath}/whisper.cpp/build/ggml/src",
      "#{buildpath}/whisper.cpp/build/ggml/src/ggml-metal",
      "#{buildpath}/whisper.cpp/build/ggml/src/ggml-blas",
    ].join(":")
    ldflags = "-lwhisper -lggml -lggml-base -lggml-cpu -lggml-blas -lggml-metal " \
              "-lm -lstdc++ -framework Accelerate -framework Metal " \
              "-framework Foundation -framework CoreGraphics"

    ENV["C_INCLUDE_PATH"] = whisper_inc
    ENV["LIBRARY_PATH"] = whisper_lib
    ENV["CGO_LDFLAGS"] = ldflags
    ENV["CGO_ENABLED"] = "1"

    system "go", "build", "-trimpath", "-o", bin/"whisper-ihm", "."
  end

  def caveats
    <<~EOS
      You need a whisper model to transcribe audio. Download one with:
        mkdir -p #{var}/whisper-ihm
        curl -L -o #{var}/whisper-ihm/ggml-large-v3.bin \\
          https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin

      Then run:
        whisper-ihm -model #{var}/whisper-ihm/ggml-large-v3.bin recording.mp3
    EOS
  end

  test do
    assert_match "Usage:", shell_output("#{bin}/whisper-ihm -help 2>&1", 0)
  end
end
