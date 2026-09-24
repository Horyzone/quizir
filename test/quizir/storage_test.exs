defmodule Quizir.StorageTest do
  use ExUnit.Case, async: true

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

  describe "upload_file/2 and delete_file/1 local fallback" do
    test "uploads file to local storage when S3 is not configured and deletes it" do
      tmp_dir = System.tmp_dir!()
      tmp_path = Path.join(tmp_dir, "test_upload_image_#{System.unique_integer([:positive])}.png")
      File.write!(tmp_path, <<137, 80, 78, 71, 13, 10, 26, 10>>)

      assert {:ok, url} = Storage.upload_file(tmp_path, "my_avatar.png")
      assert String.starts_with?(url, "/uploads/")
      assert String.ends_with?(url, ".png")

      priv_dir = :code.priv_dir(:quizir) || "priv"
      local_path = Path.join([priv_dir, "static", String.trim_leading(url, "/")])
      assert File.exists?(local_path)

      # Cleanup via delete_file
      assert :ok = Storage.delete_file(url)
      refute File.exists?(local_path)

      File.rm(tmp_path)
    end
  end
end
