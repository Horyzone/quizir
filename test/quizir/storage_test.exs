defmodule Quizir.StorageTest do
  use ExUnit.Case, async: false

  alias Quizir.Storage

  describe "s3_configured?/1 and get_s3_config/1" do
    test "returns false when S3 env vars are missing" do
      empty_env = fn _var -> nil end
      refute Storage.s3_configured?(empty_env)
    end

    test "returns true when S3_BUCKET, S3_ACCESS_KEY_ID, and S3_SECRET_ACCESS_KEY are set" do
      env_map = %{
        "S3_BUCKET" => "my-bucket",
        "S3_ACCESS_KEY_ID" => "key123",
        "S3_SECRET_ACCESS_KEY" => "secret123",
        "S3_REGION" => "eu-west-3"
      }

      env_getter = fn var -> Map.get(env_map, var) end

      assert Storage.s3_configured?(env_getter)
      config = Storage.get_s3_config(env_getter)
      assert config.bucket == "my-bucket"
      assert config.access_key_id == "key123"
      assert config.secret_access_key == "secret123"
      assert config.region == "eu-west-3"
    end

    test "supports AWS_* fallback environment variable names" do
      env_map = %{
        "AWS_S3_BUCKET" => "my-aws-bucket",
        "AWS_ACCESS_KEY_ID" => "aws-key",
        "AWS_SECRET_ACCESS_KEY" => "aws-secret",
        "AWS_REGION" => "eu-central-1",
        "AWS_ENDPOINT_URL_S3" => "https://s3.custom.com"
      }

      env_getter = fn var -> Map.get(env_map, var) end

      assert Storage.s3_configured?(env_getter)
      config = Storage.get_s3_config(env_getter)
      assert config.bucket == "my-aws-bucket"
      assert config.access_key_id == "aws-key"
      assert config.secret_access_key == "aws-secret"
      assert config.region == "eu-central-1"
      assert config.endpoint == "https://s3.custom.com"
    end
  end

  describe "upload_file/2 and delete_file/1" do
    test "returns {:error, :s3_not_configured} when S3 is not configured" do
      tmp_dir = System.tmp_dir!()
      tmp_path = Path.join(tmp_dir, "test_file_#{System.unique_integer([:positive])}.png")
      File.write!(tmp_path, "fake data")

      assert {:error, :s3_not_configured} = Storage.upload_file(tmp_path, "photo.png")

      File.rm(tmp_path)
    end

    test "uploads file when S3 is configured" do
      tmp_dir = System.tmp_dir!()
      tmp_path = Path.join(tmp_dir, "test_file_#{System.unique_integer([:positive])}.png")
      File.write!(tmp_path, "fake data")

      Application.put_env(:quizir, :s3_configured_override, true)

      Application.put_env(:quizir, :storage_test_uploader, fn _path, original_filename ->
        {:ok, "https://s3.example.com/uploads/#{original_filename}"}
      end)

      on_exit(fn ->
        Application.put_env(:quizir, :s3_configured_override, false)
        Application.delete_env(:quizir, :storage_test_uploader)
      end)

      assert {:ok, url} = Storage.upload_file(tmp_path, "actor.png")
      assert url == "https://s3.example.com/uploads/actor.png"

      File.rm(tmp_path)
    end

    test "delete_file/1 handles url safely" do
      assert :ok = Storage.delete_file("https://s3.example.com/uploads/actor.png")
      assert :ok = Storage.delete_file(nil)
    end

    test "build_s3_req/1 configures Req with custom endpoint without invalid sigv4 options" do
      config = %{
        bucket: "quizir-media",
        access_key_id: "test_key",
        secret_access_key: "test_secret",
        region: "eu-west-3",
        endpoint: "https://s3.eu-west-3.amazonaws.com",
        public_url: "https://s3.eu-west-3.amazonaws.com/quizir-media"
      }

      req = Storage.build_s3_req(config)

      assert req.options[:aws_endpoint_url_s3] == "https://s3.eu-west-3.amazonaws.com"
      assert req.options[:aws_sigv4][:access_key_id] == "test_key"
      assert req.options[:aws_sigv4][:secret_access_key] == "test_secret"
      assert req.options[:aws_sigv4][:region] == "eu-west-3"
      # Crucial: :endpoint_url must not be inside :aws_sigv4 as Req 0.7 rejects it
      refute Keyword.has_key?(req.options[:aws_sigv4], :endpoint_url)

      # Test that the pipeline handles an s3:// URL without raising ArgumentError
      req =
        req
        |> Req.merge(url: "s3://quizir-media/uploads/photo.png", body: "image_data")
        |> ReqS3.handle_s3_url()
        |> Req.Steps.put_aws_sigv4()

      assert req.url.host == "s3.eu-west-3.amazonaws.com"
      assert req.url.path == "/quizir-media/uploads/photo.png"
      assert [auth_header] = Req.Request.get_header(req, "authorization")
      assert auth_header =~ "AWS4-HMAC-SHA256"
    end
  end

  describe "image limits and optimization" do
    test "max_image_bytes/0 returns 500 KiB (512_000 bytes)" do
      assert Storage.max_image_bytes() == 512_000
    end

    test "max_dimension/0 returns 1024 px" do
      assert Storage.max_dimension() == 1024
    end

    test "optimize_and_validate/2 accepts small files and returns path" do
      tmp_dir = System.tmp_dir!()
      tmp_path = Path.join(tmp_dir, "small_#{System.unique_integer([:positive])}.png")
      File.write!(tmp_path, "small payload")
      on_exit(fn -> File.rm(tmp_path) end)

      assert {:ok, path, false} = Storage.optimize_and_validate(tmp_path, ".png")
      assert path == tmp_path
    end

    test "optimize_and_validate/2 rejects files exceeding 500 KiB" do
      tmp_dir = System.tmp_dir!()
      tmp_path = Path.join(tmp_dir, "heavy_#{System.unique_integer([:positive])}.png")
      # Write 600 KiB
      File.write!(tmp_path, :crypto.strong_rand_bytes(600 * 1024))
      on_exit(fn -> File.rm(tmp_path) end)

      assert {:error, :file_too_large} = Storage.optimize_and_validate(tmp_path, ".png")
    end

    test "optimize_and_validate/2 resizes image exceeding 1024x1024 if optimizer is available" do
      if ffmpeg = System.find_executable("ffmpeg") do
        tmp_dir = System.tmp_dir!()
        src_path = Path.join(tmp_dir, "large_img_#{System.unique_integer([:positive])}.png")

        System.cmd(
          ffmpeg,
          [
            "-y",
            "-f",
            "lavfi",
            "-i",
            "color=c=blue:s=1200x1200",
            "-frames:v",
            "1",
            "-update",
            "1",
            src_path
          ],
          stderr_to_stdout: true
        )

        if File.exists?(src_path) do
          on_exit(fn -> File.rm(src_path) end)

          assert {:ok, opt_path, true} = Storage.optimize_and_validate(src_path, ".png")
          on_exit(fn -> File.rm(opt_path) end)

          assert File.exists?(opt_path)
          assert {:ok, %{size: size}} = File.stat(opt_path)
          assert size <= Storage.max_image_bytes()
        end
      end
    end

    test "upload_file/2 rejects file larger than 500 KiB before s3 upload" do
      tmp_dir = System.tmp_dir!()
      tmp_path = Path.join(tmp_dir, "huge_#{System.unique_integer([:positive])}.jpg")
      File.write!(tmp_path, :crypto.strong_rand_bytes(600 * 1024))

      Application.put_env(:quizir, :s3_configured_override, true)

      on_exit(fn ->
        Application.put_env(:quizir, :s3_configured_override, false)
        File.rm(tmp_path)
      end)

      assert {:error, :file_too_large} = Storage.upload_file(tmp_path, "huge.jpg")
    end
  end
end
